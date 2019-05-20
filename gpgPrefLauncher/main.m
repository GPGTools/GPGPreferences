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
		NSMutableDictionary *userInfo = [NSMutableDictionary new];
		NSArray <NSString *> *arguments = [[NSProcessInfo processInfo] arguments];
		
		if (arguments.count >= 2) {
			if (arguments[1].length > 0 && [arguments[1] characterAtIndex:0] == '-') {
				NSDictionary *parsedArguments = [[NSUserDefaults standardUserDefaults] volatileDomainForName:NSArgumentDomain];

				if (parsedArguments[@"tab"]) {
					userInfo[@"tab"] = parsedArguments[@"tab"];
				}
				if (parsedArguments[@"tool"]) {
					userInfo[@"tool"] = parsedArguments[@"tool"];
				}
			} else {
				// Old variant: The tab to select is the only argument.
				userInfo[@"tab"] = arguments[1];
			}
			
			NSString *directory = [NSString stringWithFormat:@"/private/tmp/GPGPreferences.%@", NSUserName()];
			NSString *path = [directory stringByAppendingPathComponent:@"tab"];
			[[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:NO attributes:nil error:nil];
			
			if (![userInfo writeToFile:path atomically:YES]) {
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
		
		if (userInfo.count > 0) {
			[[NSDistributedNotificationCenter defaultCenter] postNotificationName:GPGPreferencesShowTabNotification object:nil userInfo:userInfo deliverImmediately:YES];
		}
		
	}
	return 0;
}

