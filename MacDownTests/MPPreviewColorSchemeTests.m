//
//  MPPreviewColorSchemeTests.m
//  MacDownTests
//
//  Pins the WebKit behaviour the paired dark preview stylesheet depends on
//  (GitHub issue #292): the legacy WebView evaluates prefers-color-scheme from
//  its effective appearance, re-evaluates it live when the appearance changes
//  on an already loaded page, and reports the light scheme when printing, so
//  PDF export and Print keep the light theme.
//
//  The page colours its text (backgrounds are not printed by default) red
//  under the light query and blue under the dark query, and fills the page
//  with block glyphs so the printed PDF can be sampled for either colour.
//

#import <XCTest/XCTest.h>
#import <WebKit/WebKit.h>
#import <Quartz/Quartz.h>


static NSString * const kMPColorSchemePage =
    @"<!DOCTYPE html><html><head>"
    @"<style media=\"(prefers-color-scheme: light)\">body{color:#ff0000}</style>"
    @"<style media=\"(prefers-color-scheme: dark)\">body{color:#0000ff}</style>"
    @"<style>body{margin:0;font:160px Menlo,monospace;line-height:1}</style>"
    @"</head><body>"
    @"■■■<br>■■■<br>■■■<br>"
    @"■■■<br>■■■"
    @"</body></html>";

static NSString * const kMPDarkMatchesScript =
    @"String(window.matchMedia('(prefers-color-scheme: dark)').matches)";
static NSString * const kMPBodyColorScript =
    @"getComputedStyle(document.body).color";
static NSString * const kMPInstallChangeListenerScript =
    @"window.__mpSchemeChanges = 0;"
    @"window.matchMedia('(prefers-color-scheme: dark)')"
    @".addListener(function(){ window.__mpSchemeChanges++; });"
    @"'ok'";
static NSString * const kMPChangeCountScript = @"String(window.__mpSchemeChanges)";


@interface MPPreviewColorSchemeTests : XCTestCase
@property (strong) WebView *webView;
@end


@implementation MPPreviewColorSchemeTests

- (void)setUp
{
    [super setUp];
    self.webView = [[WebView alloc] initWithFrame:NSMakeRect(0, 0, 600, 800)
                                        frameName:nil groupName:nil];
    self.webView.appearance =
        [NSAppearance appearanceNamed:NSAppearanceNameAqua];
    [self.webView.mainFrame loadHTMLString:kMPColorSchemePage baseURL:nil];
    [self waitForLoad];
}

- (void)tearDown
{
    self.webView = nil;
    [super tearDown];
}


#pragma mark - Helpers

- (NSString *)evaluate:(NSString *)script
{
    return [self.webView stringByEvaluatingJavaScriptFromString:script];
}

- (void)spinRunLoop:(NSTimeInterval)seconds
{
    [[NSRunLoop currentRunLoop]
        runUntilDate:[NSDate dateWithTimeIntervalSinceNow:seconds]];
}

- (void)waitForLoad
{
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:5.0];
    while ([deadline timeIntervalSinceNow] > 0)
    {
        NSString *state = [self evaluate:@"document.readyState"];
        if (!self.webView.isLoading && [state isEqualToString:@"complete"])
            return;
        [self spinRunLoop:0.02];
    }
    XCTFail(@"WebView did not finish loading");
}

- (void)setAppearanceNamed:(NSAppearanceName)name
{
    self.webView.appearance = [NSAppearance appearanceNamed:name];
    [self spinRunLoop:0.1];
}

// Print the loaded page to a PDF and return its first page.
- (PDFPage *)printedFirstPage
{
    NSString *filename = [NSString stringWithFormat:@"%@.pdf",
                          NSUUID.UUID.UUIDString];
    NSURL *url = [NSURL fileURLWithPath:
                  [NSTemporaryDirectory() stringByAppendingPathComponent:filename]];

    NSPrintInfo *printInfo = [[NSPrintInfo alloc] init];
    printInfo.topMargin = 0;
    printInfo.bottomMargin = 0;
    printInfo.leftMargin = 0;
    printInfo.rightMargin = 0;
    printInfo.jobDisposition = NSPrintSaveJob;
    [printInfo.dictionary setObject:url forKey:NSPrintJobSavingURL];

    NSPrintOperation *operation =
        [self.webView.mainFrame.frameView printOperationWithPrintInfo:printInfo];
    operation.showsPrintPanel = NO;
    operation.showsProgressPanel = NO;
    XCTAssertTrue([operation runOperation], @"Print to PDF must succeed");

    PDFDocument *pdf = [[PDFDocument alloc] initWithURL:url];
    [[NSFileManager defaultManager] removeItemAtURL:url error:NULL];
    XCTAssertNotNil(pdf, @"Printed PDF must be readable");
    return [pdf pageAtIndex:0];
}

// Count clearly red and clearly blue pixels in a thumbnail of the page.
- (void)countRedPixels:(NSUInteger *)red bluePixels:(NSUInteger *)blue
                inPage:(PDFPage *)page
{
    NSImage *image = [page thumbnailOfSize:NSMakeSize(200, 260)
                                    forBox:kPDFDisplayBoxMediaBox];
    NSBitmapImageRep *bitmap =
        [[NSBitmapImageRep alloc] initWithData:image.TIFFRepresentation];
    *red = 0;
    *blue = 0;
    for (NSInteger y = 0; y < bitmap.pixelsHigh; y += 2)
    {
        for (NSInteger x = 0; x < bitmap.pixelsWide; x += 2)
        {
            NSColor *color = [[bitmap colorAtX:x y:y]
                colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
            if (color.alphaComponent < 0.5)
                continue;
            BOOL isRed = color.redComponent > 0.7 && color.greenComponent < 0.3
                         && color.blueComponent < 0.3;
            BOOL isBlue = color.blueComponent > 0.7 && color.redComponent < 0.3
                          && color.greenComponent < 0.3;
            if (isRed)
                (*red)++;
            if (isBlue)
                (*blue)++;
        }
    }
}


#pragma mark - Tests

- (void)testLightAppearanceSelectsLightSheet
{
    XCTAssertEqualObjects([self evaluate:kMPDarkMatchesScript], @"false");
    XCTAssertEqualObjects([self evaluate:kMPBodyColorScript], @"rgb(255, 0, 0)");
}

- (void)testAppearanceChangeOnLoadedPageSwitchesSheetWithoutReload
{
    XCTAssertEqualObjects([self evaluate:kMPInstallChangeListenerScript], @"ok");

    [self setAppearanceNamed:NSAppearanceNameDarkAqua];

    XCTAssertEqualObjects([self evaluate:kMPDarkMatchesScript], @"true");
    XCTAssertEqualObjects([self evaluate:kMPBodyColorScript], @"rgb(0, 0, 255)");
    XCTAssertEqualObjects([self evaluate:kMPChangeCountScript], @"1",
                          @"The media query list must fire a change event");

    [self setAppearanceNamed:NSAppearanceNameAqua];

    XCTAssertEqualObjects([self evaluate:kMPDarkMatchesScript], @"false");
    XCTAssertEqualObjects([self evaluate:kMPBodyColorScript], @"rgb(255, 0, 0)");
}

- (void)testPrintingUnderDarkAppearanceUsesLightSheet
{
    [self setAppearanceNamed:NSAppearanceNameDarkAqua];
    XCTAssertEqualObjects([self evaluate:kMPDarkMatchesScript], @"true",
                          @"Precondition: the screen rendering is dark");

    PDFPage *page = [self printedFirstPage];
    XCTAssertNotNil(page);

    NSUInteger red = 0;
    NSUInteger blue = 0;
    [self countRedPixels:&red bluePixels:&blue inPage:page];
    XCTAssertGreaterThan(red, 0u, @"The printed page must use the light sheet");
    XCTAssertLessThanOrEqual(blue, red / 100,
                             @"The printed page must not use the dark sheet");
}

@end
