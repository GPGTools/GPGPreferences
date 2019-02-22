//
//  main.m
//  gpgPrefLauncher
//
//  Created by Mento on 13.04.16.
//  Copyright © 2019. All rights reserved.
//

#import <Cocoa/Cocoa.h>

static NSString * const GPGPreferencesShowTabNotification = @"GPGPreferencesShowTabNotification";

int main(int argc, const char *argv[]) {
	@autoreleasepool {
		NSString *tab = nil;
		
		NSArray <NSString *> *arguments = [[NSProcessInfo processInfo] arguments];
		if (arguments.count >= 2) {
			tab = arguments[1];
			NSString *directory = [NSString stringWithFormat:@"/private/tmp/GPGPreferences.%@", NSUserName()];
			NSString *path = [directory stringByAppendingPathComponent:@"tab"];
			[[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:NO attributes:nil error:nil];
			if (![tab writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil]) {
				return 1;
			}
		}
		
		NSString *panePath = @"/Library/PreferencePanes/GPGPreferences.prefPane";
		if (![[NSFileManager defaultManager] fileExistsAtPath:panePath]) {
			panePath = [NSHomeDirectory() stringByAppendingPathComponent:panePath];
			if (![[NSFileManager defaultManager] fileExistsAtPath:panePath]) {
				return 2;
			}
		}
		
		NSURL *appURL = [NSURL fileURLWithPath:@"/Applications/System Preferences.app"];
		NSURL *paneURL = [NSURL fileURLWithPath:panePath];

		NSRunningApplication *application = [[NSWorkspace sharedWorkspace] openURLs:@[paneURL] withApplicationAtURL:appURL options:0 configuration:@{} error:nil];
		if (!application) {
			return 3;
		}
		
		if (tab) {
			[[NSDistributedNotificationCenter defaultCenter] postNotificationName:GPGPreferencesShowTabNotification object:nil userInfo:@{@"tab": tab} deliverImmediately:YES];
		}
		
	}
	return 0;
}

