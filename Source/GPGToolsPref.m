//
//  GPGToolsPref.m
//  GPGTools
//
//  Created by Alexander Willner on 04.08.10.
//  Copyright (c) 2010 GPGTools Project Team. All rights reserved.
//

#import "GPGToolsPref.h"
#import <Libmacgpg/Libmacgpg.h>
#import "NSBundle+Sandbox.h"

@implementation GPGToolsPref

+ (void)initialize {
#ifndef DEBUG
    // Check the validity of the code signature.
    if([[NSBundle bundleForClass:[self class]] ob_codeSignState] != OBCodeSignStateSignatureValid) {
        NSRunAlertPanel(@"Someone tampered with your installation of GPGPreferences!", @"To keep you safe, GPGPreferences will not be loaded!\n\nPlease download and install the latest version of GPG Suite from https://gpgtools.org to be sure you have an original version from us!", @"", nil, nil, nil);
        exit(1);
    }
#endif
}

- (NSString *)mainNibName {
	if (![GPGController class]) {
		return @"WarningView";
	}
	return [super mainNibName];
}

- (void) mainViewDidLoad {
}

@end
