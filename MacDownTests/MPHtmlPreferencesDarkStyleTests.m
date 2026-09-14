//
//  MPHtmlPreferencesDarkStyleTests.m
//  MacDownTests
//
//  Tests for the "Dark CSS" popup in the Rendering preferences pane
//  (GitHub issue #292). It offers the same stylesheets as the "CSS" popup,
//  with an empty first item that turns the pairing off.
//

#import <XCTest/XCTest.h>
#import <Cocoa/Cocoa.h>
#import "MPHtmlPreferencesViewController.h"
#import "MPPreferences.h"


@interface MPHtmlPreferencesViewController (DarkStyleTesting)
@property (weak) NSPopUpButton *stylesheetSelect;
@property (weak) NSPopUpButton *darkStylesheetSelect;
- (IBAction)changeDarkStylesheet:(NSPopUpButton *)sender;
@end


@interface MPHtmlPreferencesDarkStyleTests : XCTestCase
@property (strong) MPHtmlPreferencesViewController *controller;
@property (strong) MPPreferences *preferences;
@property (copy) NSString *originalDarkStyleName;
@end


@implementation MPHtmlPreferencesDarkStyleTests

- (void)setUp
{
    [super setUp];
    self.preferences = [MPPreferences sharedInstance];
    self.originalDarkStyleName = self.preferences.htmlDarkStyleName;
    self.controller = [[MPHtmlPreferencesViewController alloc] init];
    (void)self.controller.view;     // Load the nib and connect outlets.
}

- (void)tearDown
{
    self.preferences.htmlDarkStyleName = self.originalDarkStyleName;
    [self.preferences synchronize];
    self.controller = nil;
    [super tearDown];
}

- (void)testDarkPopupOffersSameThemesAsLightPopupAndSelectsCurrentOne
{
    self.preferences.htmlDarkStyleName = @"Github2 (dark)";

    [self.controller viewWillAppear];

    NSPopUpButton *dark = self.controller.darkStylesheetSelect;
    XCTAssertNotNil(dark, @"The Dark CSS popup must be connected");
    XCTAssertEqualObjects(dark.itemTitles,
                          self.controller.stylesheetSelect.itemTitles,
                          @"Both popups list the same stylesheets");
    XCTAssertEqualObjects(dark.itemTitles.firstObject, @"",
                          @"The first item is the empty 'off' choice");
    XCTAssertEqualObjects(dark.selectedItem.title, @"Github2 (dark)",
                          @"The current preference is preselected");
}

- (void)testChoosingDarkThemeStoresPreference
{
    [self.controller viewWillAppear];
    NSPopUpButton *dark = self.controller.darkStylesheetSelect;

    [dark selectItemWithTitle:@"Solarized (Dark)"];
    [self.controller changeDarkStylesheet:dark];

    XCTAssertEqualObjects(self.preferences.htmlDarkStyleName,
                          @"Solarized (Dark)");
}

- (void)testChoosingEmptyItemClearsPreference
{
    self.preferences.htmlDarkStyleName = @"Github2 (dark)";
    [self.controller viewWillAppear];
    NSPopUpButton *dark = self.controller.darkStylesheetSelect;

    [dark selectItemAtIndex:0];
    [self.controller changeDarkStylesheet:dark];

    XCTAssertNil(self.preferences.htmlDarkStyleName,
                 @"The empty item turns the dark theme off");
}

@end
