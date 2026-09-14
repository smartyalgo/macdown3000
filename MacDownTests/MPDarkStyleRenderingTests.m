//
//  MPDarkStyleRenderingTests.m
//  MacDownTests
//
//  Tests for the paired dark preview stylesheet (GitHub issue #292).
//  The renderer emits the light theme gated on (prefers-color-scheme: light)
//  and the dark theme gated on (prefers-color-scheme: dark), so WebKit picks
//  the sheet from the view's effective appearance and re-evaluates it live.
//

#import <XCTest/XCTest.h>
#import "MPRenderer.h"
#import "MPRendererTestHelpers.h"
#import "MPUtilities.h"


static NSString * const kMPLightQuery = @"(prefers-color-scheme: light)";
static NSString * const kMPDarkQuery = @"(prefers-color-scheme: dark)";

// The exact <link> tag MPStyleSheet emits for a bundled style, with or
// without a media attribute.
static NSString *MPLinkTagForStyle(NSString *name, NSString *media)
{
    NSURL *url = [NSURL fileURLWithPath:MPStylePathForName(name)];
    NSString *mediaAttribute = @"";
    if (media)
        mediaAttribute = [NSString stringWithFormat:@" media=\"%@\"", media];
    return [NSString stringWithFormat:
            @"<link rel=\"stylesheet\" type=\"text/css\"%@ href=\"%@\">",
            mediaAttribute, url.absoluteString];
}

static NSString *MPStyleTagOpeningForMedia(NSString *media)
{
    return [NSString stringWithFormat:@"<style type=\"text/css\" media=\"%@\">",
            media];
}


@interface MPDarkStyleRenderingTests : XCTestCase
@property (nonatomic, strong) MPRenderer *renderer;
@property (nonatomic, strong) MPMockRendererDataSource *dataSource;
@property (nonatomic, strong) MPMockRendererDelegate *delegate;
@end


@implementation MPDarkStyleRenderingTests

- (void)setUp
{
    [super setUp];
    self.dataSource = [[MPMockRendererDataSource alloc] init];
    self.dataSource.markdown = @"# Appearance";
    self.delegate = [[MPMockRendererDelegate alloc] init];
    self.delegate.styleName = @"GitHub2";

    self.renderer = [[MPRenderer alloc] init];
    self.renderer.dataSource = self.dataSource;
    self.renderer.delegate = self.delegate;
}

- (void)tearDown
{
    self.renderer = nil;
    self.dataSource = nil;
    self.delegate = nil;
    [super tearDown];
}

- (NSString *)renderedHTML
{
    [self.renderer parseMarkdown:self.dataSource.markdown];
    [self.renderer render];
    return self.delegate.lastHTML;
}


#pragma mark - Preview <link> emission

- (void)testLightAndDarkLinksAreGatedOnColorSchemeInLightThenDarkOrder
{
    self.delegate.darkStyleName = @"Github2 (dark)";

    NSString *html = [self renderedHTML];

    NSRange light = [html rangeOfString:MPLinkTagForStyle(@"GitHub2",
                                                          kMPLightQuery)];
    NSRange dark = [html rangeOfString:MPLinkTagForStyle(@"Github2 (dark)",
                                                         kMPDarkQuery)];
    XCTAssertNotEqual(light.location, NSNotFound,
                      @"Light theme must be linked with the light query");
    XCTAssertNotEqual(dark.location, NSNotFound,
                      @"Dark theme must be linked with the dark query");
    XCTAssertLessThan(light.location, dark.location,
                      @"Light sheet must precede the dark sheet");
}

- (void)testNoDarkThemeEmitsPlainLightLinkWithoutMediaAttribute
{
    self.delegate.darkStyleName = nil;

    NSString *html = [self renderedHTML];

    XCTAssertTrue([html containsString:MPLinkTagForStyle(@"GitHub2", nil)],
                  @"Without a dark theme the light link is unchanged");
    XCTAssertFalse([html containsString:@"media="],
                   @"No media attribute may appear when dark mode is off");
}

- (void)testDarkThemeWithoutLightThemeEmitsOnlyTheDarkLink
{
    self.delegate.styleName = nil;
    self.delegate.darkStyleName = @"Github2 (dark)";

    NSString *html = [self renderedHTML];

    XCTAssertTrue([html containsString:MPLinkTagForStyle(@"Github2 (dark)",
                                                         kMPDarkQuery)]);
    XCTAssertFalse([html containsString:@"GitHub2.css"],
                   @"No light sheet is linked when none is configured");
}


#pragma mark - Change tracking

- (void)testChangingDarkThemeTriggersReRenderWithNewSheet
{
    self.delegate.darkStyleName = @"Github2 (dark)";
    [self renderedHTML];
    self.delegate.lastHTML = nil;

    self.delegate.darkStyleName = @"Solarized (Dark)";
    [self.renderer renderIfPreferencesChanged];

    XCTAssertNotNil(self.delegate.lastHTML,
                    @"A new dark theme must re-render");
    XCTAssertTrue([self.delegate.lastHTML containsString:
                   MPLinkTagForStyle(@"Solarized (Dark)", kMPDarkQuery)]);
}

- (void)testUnchangedDarkThemeDoesNotReRender
{
    self.delegate.darkStyleName = @"Github2 (dark)";
    [self renderedHTML];
    self.delegate.lastHTML = nil;

    [self.renderer renderIfPreferencesChanged];

    XCTAssertNil(self.delegate.lastHTML,
                 @"No preference changed, so nothing should re-render");
}


#pragma mark - HTML export

- (void)testExportEmbedsBothSheetsGatedOnColorScheme
{
    self.delegate.darkStyleName = @"Github2 (dark)";
    [self.renderer parseMarkdown:self.dataSource.markdown];

    NSString *html = [self.renderer HTMLForExportWithStyles:YES
                                               highlighting:NO];

    XCTAssertTrue([html containsString:MPStyleTagOpeningForMedia(kMPLightQuery)],
                  @"Export must embed the light sheet gated on the light query");
    XCTAssertTrue([html containsString:MPStyleTagOpeningForMedia(kMPDarkQuery)],
                  @"Export must embed the dark sheet gated on the dark query");
}

@end
