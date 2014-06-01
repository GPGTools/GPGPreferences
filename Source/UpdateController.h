//
//  UpdateController.h
//  GPGPreferences
//
//  Created by Mento on 26.04.2013
//
//

#import <Foundation/Foundation.h>
#import <Sparkle/Sparkle.h>


@interface UpdateController : NSObject

- (void)checkForUpdatesForTool:(NSString *)tool;
- (IBAction)copyVersionInfo:(NSButton *)sender;
- (IBAction)openDownloadSite:(id)sender;

@end
