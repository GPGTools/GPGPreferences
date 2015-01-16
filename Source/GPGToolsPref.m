//
//  GPGToolsPref.m
//  GPGTools
//
//  Created by Alexander Willner on 04.08.10.
//  Copyright (c) 2010 GPGTools Project Team. All rights reserved.
//

#import "GPGToolsPref.h"
#import <Libmacgpg/Libmacgpg.h>

NSBundle *gpgPreferencesBundle;

@implementation GPGToolsPref

- (NSString *)mainNibName {
	if (![GPGController class]) {
		return @"WarningView";
	}
	gpgPreferencesBundle = [NSBundle bundleForClass:[self class]];
#ifdef CODE_SIGN_CHECK
	/* Check the validity of the code signature. */
    if (!gpgPreferencesBundle.isValidSigned) {
		NSRunAlertPanel(@"Someone tampered with your installation of GPGPreferences!",
						@"To keep you safe, GPGPreferences will not be loaded!\n\nPlease download and install the latest version of GPG Suite from https://gpgtools.org to be sure you have an original version from us!", nil, nil, nil);
        exit(1);
    }
#endif
	return [super mainNibName];
}

- (void)willUnselect {
	[self.mainView.window makeFirstResponder:nil];
}

@end


void WarningPanel(NSString *title, NSString *msg) {
	NSAlert *alert = [[NSAlert alloc] init];
	alert.messageText = title;
	alert.informativeText = msg;
	
	NSImage *image = [NSImage imageNamed:@"gpgprefs"];
	if (!image) {
		image = [[NSImage alloc] initByReferencingFile:[gpgPreferencesBundle pathForImageResource:@"gpgprefs"]];
		[image setName:@"gpgprefs"];
	}
	alert.icon = image;
	[alert runModal];
}

