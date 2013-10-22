//
//  GPGToolsPref.m
//  GPGTools
//
//  Created by Alexander Willner on 04.08.10.
//  Copyright (c) 2010 GPGTools Project Team. All rights reserved.
//

#import "GPGToolsPref.h"
#import <Libmacgpg/Libmacgpg.h>

@implementation GPGToolsPref

- (NSString *)mainNibName {
	if (![GPGController class]) {
		return @"WarningView";
	}
#ifdef CODE_SIGN_CHECK
	/* Check the validity of the code signature. */
    if (![NSBundle bundleForClass:[self class]].isValidSigned) {
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
