//
//  main.m
//  gpgPrefLauncher
//
//  Created by Mento on 13.04.16.
//  Copyright (c) 2016 GPGTools. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SBSystemPreferences.h"


int main(int argc, const char *argv[]) {
	@autoreleasepool {
		SBSystemPreferencesApplication *systemPrefs = [SBApplication applicationWithBundleIdentifier:@"com.apple.systempreferences"];
		if (!systemPrefs) {
			return 1;
		}
		BOOL running = systemPrefs.isRunning;
		SBElementArray *panes = systemPrefs.panes;
		SBSystemPreferencesPane *gpgPane = nil;
		
		
		for (SBSystemPreferencesPane *pane in panes) {
			if ([pane.id isEqualToString:@"org.gpgtools.gpgpreferences"]) {
				gpgPane = pane;
				break;
			}
		}
		if (gpgPane) {
			NSArray *arguments = [[NSProcessInfo processInfo] arguments];
			if (arguments.count < 2) {
				[gpgPane reveal];
				[systemPrefs activate];
				return 0;
			}
			NSString *tab = arguments[1];
			if ([tab isKindOfClass:[NSString class]]) {
				SBElementArray *anchors = gpgPane.anchors;
				
				for (SBSystemPreferencesAnchor *anchor in anchors) {
					if ([anchor.name isEqualToString:tab]) {
						[systemPrefs activate];
						[anchor reveal];
						return 0;
					}
				}
			}
		}
		
		
		if (running == NO) {
			[systemPrefs quitSaving:SBSystemPreferencesSaveOptionsNo];
		}
	}
    return 1;
}
