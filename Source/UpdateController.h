//
//  UpdateController.h
//  GPGPreferences
//
//  Created by Mento on 26.04.2013
//
//

#import <Foundation/Foundation.h>
#import <Sparkle/Sparkle.h>
#import "GPGToolsPref.h"

@interface UpdateController : NSObject {
	SUUpdater *updater;
	NSBundle *bundle;
}
@property (assign, readonly) NSBundle *bundle;

- (void)checkForUpdatesForTool:(NSString *)tool;
- (IBAction)copyVersionInfo:(NSButton *)sender;
- (IBAction)openDownloadSite:(id)sender;

@end
