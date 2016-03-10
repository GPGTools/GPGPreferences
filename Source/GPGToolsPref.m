//
//  GPGToolsPref.m
//  GPGTools
//
//  Created by Alexander Willner on 04.08.10.
//  Copyright (c) 2010 GPGTools Project Team. All rights reserved.
//

#import "GPGToolsPref.h"
#import <Libmacgpg/Libmacgpg.h>

GPGToolsPref *gpgToolsPrefPane = nil;

@implementation GPGToolsPref

- (instancetype)initWithBundle:(NSBundle *)bundle {
	self = [super initWithBundle:bundle];
	if (self == nil) {
		return nil;
	}
	gpgToolsPrefPane = [self retain];
	return self;
}

- (NSString *)mainNibName {
	if (![GPGController class]) {
		return @"WarningView";
	}
#ifdef CODE_SIGN_CHECK
	/* Check the validity of the code signature. */
    if (!self.bundle.isValidSigned) {
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


- (void)panelWithTitle:(NSString *)title message:(NSString *)msg {
	NSAlert *alert = [[NSAlert alloc] init];
	alert.messageText = title;
	alert.informativeText = msg;
	
	NSImage *image = [NSImage imageNamed:@"GPGTools"];
	if (!image) {
		image = [[NSImage alloc] initByReferencingFile:[self.bundle pathForImageResource:@"GPGTools"]];
		[image setName:@"GPGTools"];
	}
	alert.icon = image;
	
	
	if (NSAppKitVersionNumber >= NSAppKitVersionNumber10_9) {
		[alert beginSheetModalForWindow:self.mainView.window completionHandler:^(NSModalResponse returnCode) {}];
	} else {
		[alert runModal];
	}
}


@end



