//
//  MPHtmlPreferencesDiagramTogglesTests.m
//  MacDownTests
//
//  The Graphviz and Mermaid checkboxes in the Rendering preferences pane work
//  regardless of the Syntax Highlighting setting, matching the renderer, which
//  loads the diagram scripts on their own toggles (GitHub issue #533).
//

#import <XCTest/XCTest.h>
#import <Cocoa/Cocoa.h>
#import "MPHtmlPreferencesViewController.h"
#import "MPPreferences.h"


/// Returns the first NSButton under @c view whose title is @c title, or nil.
static NSButton *MPButtonTitled(NSView *view, NSString *title)
{
    if ([view isKindOfClass:[NSButton class]]
        && [((NSButton *)view).title isEqualToString:title])
        return (NSButton *)view;
    for (NSView *sub in view.subviews)
    {
        NSButton *found = MPButtonTitled(sub, title);
        if (found)
            return found;
    }
    return nil;
}


@interface MPHtmlPreferencesDiagramTogglesTests : XCTestCase
@property (strong) MPPreferences *preferences;
@property (assign) BOOL originalSyntaxHighlighting;
@end


@implementation MPHtmlPreferencesDiagramTogglesTests

- (void)setUp
{
    [super setUp];
    self.preferences = [MPPreferences sharedInstance];
    self.originalSyntaxHighlighting = self.preferences.htmlSyntaxHighlighting;
}

- (void)tearDown
{
    self.preferences.htmlSyntaxHighlighting = self.originalSyntaxHighlighting;
    [self.preferences synchronize];
    [super tearDown];
}

- (void)testDiagramCheckboxesStayEnabledWithSyntaxHighlightingOff
{
    // Set before the nib loads: a bound "enabled" is applied at load time.
    self.preferences.htmlSyntaxHighlighting = NO;
    MPHtmlPreferencesViewController *controller =
        [[MPHtmlPreferencesViewController alloc] init];
    NSView *view = controller.view;

    // Control: a checkbox that is a real Syntax Highlighting sub-option is
    // disabled, which proves the nib's enabled bindings took effect.
    NSButton *lineNumbers = MPButtonTitled(view, @"Show line numbers");
    XCTAssertNotNil(lineNumbers, @"Rendering pane has a line numbers checkbox");
    XCTAssertFalse(lineNumbers.enabled,
                   @"Line numbers follow Syntax Highlighting");

    for (NSString *title in @[@"Graphviz", @"Mermaid"])
    {
        NSButton *checkbox = MPButtonTitled(view, title);
        XCTAssertNotNil(checkbox, @"Rendering pane has a '%@' checkbox", title);
        XCTAssertTrue(checkbox.enabled,
                      @"'%@' must not depend on Syntax Highlighting", title);
    }
}

@end
