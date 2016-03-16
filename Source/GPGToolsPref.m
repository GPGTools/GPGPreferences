//
//  GPGToolsPref.m
//  GPGTools
//
//  Created by Alexander Willner on 04.08.10.
//  Copyright (c) 2016 GPGTools Project Team. All rights reserved.
//

#import "GPGToolsPref.h"
#import <Libmacgpg/Libmacgpg.h>

GPGToolsPref *gpgPrefPane = nil;

@implementation GPGToolsPref

- (instancetype)initWithBundle:(NSBundle *)bundle {
	self = [super initWithBundle:bundle];
	if (self == nil) {
		return nil;
	}
	gpgPrefPane = [self retain];
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


- (NSString *)localizedString:(NSString *)key {
	static NSBundle *englishBundle = nil;
	if (!englishBundle) {
		englishBundle = [[NSBundle bundleWithPath:[self.bundle pathForResource:@"en" ofType:@"lproj"]] retain];
	}
	
	NSString *notFoundValue = @"~#*?*#~";
	NSString *localized = [self.bundle localizedStringForKey:key value:notFoundValue table:nil];
	if (localized == notFoundValue) {
		localized = [englishBundle localizedStringForKey:key value:nil table:nil];
	}
	
	return localized;
}



// Alerts

- (void)localizedAlert:(NSString *)string, ... {
	va_list args;
	va_start(args, string);
	[self localizedAlert:string arguments:args completionHandler:nil];
	va_end(args);
}

- (void)localizedAlert:(NSString *)string
	 completionHandler:(void (^)(NSModalResponse returnCode))handler {
	
	[self localizedAlert:string arguments:nil completionHandler:handler];
}

- (void)localizedAlert:(NSString *)string
			parameters:(NSArray *)parameters
	 completionHandler:(void (^)(NSModalResponse returnCode))handler {
	
	NSMutableData *data = [NSMutableData dataWithLength:(sizeof(id) * parameters.count)];
	[parameters getObjects:(__unsafe_unretained id *)data.mutableBytes range:NSMakeRange(0, parameters.count)];
	
	[self localizedAlert:string arguments:data.mutableBytes completionHandler:handler];
}

- (void)localizedAlert:(NSString *)string
			 arguments:(va_list)arguments
			  completionHandler:(void (^)(NSModalResponse returnCode))handler {
	
	NSString *title = [self localizedString:[string stringByAppendingString:@"_Title"]];
	NSString *messageFormat = [self localizedString:[string stringByAppendingString:@"_Msg"]];
	
	NSString *message;
	if (arguments) {
		message = messageFormat;
	} else {
		message = [[[NSString alloc] initWithFormat:messageFormat arguments:arguments] autorelease];
	}
	
	
	NSMutableArray *buttons = nil;
	NSString *button;
	for (NSUInteger i = 1; ; i++) {
		NSString *template = [string stringByAppendingFormat:@"_Button%li", i];
		button = [self localizedString:template];
		if ([button isEqualToString:template]) {
			break;
		} else {
			if (buttons == nil) {
				buttons = [NSMutableArray array];
			}
			[buttons addObject:button];
		}
	}
	
	
	[self alertWithTitle:title message:message buttons:buttons completionHandler:handler];
}



- (void)alertWithTitle:(NSString *)title
			   message:(NSString *)msg
			   buttons:(NSArray *)buttons
			  completionHandler:(void (^)(NSModalResponse returnCode))handler {
	
	NSAlert *alert = [[NSAlert alloc] init];
	alert.messageText = title;
	alert.informativeText = msg;
	
	NSImage *image = [NSImage imageNamed:@"GPGTools"];
	if (!image) {
		image = [[NSImage alloc] initByReferencingFile:[self.bundle pathForImageResource:@"GPGTools"]];
		[image setName:@"GPGTools"];
	}
	alert.icon = image;
	for (NSString *button in buttons) {
		[alert addButtonWithTitle:button];
	}
	
	
	if (NSAppKitVersionNumber >= NSAppKitVersionNumber10_9 ) {
		[alert beginSheetModalForWindow:self.mainView.window completionHandler:^(NSModalResponse returnCode) {
			if (handler) {
				handler(returnCode);
			}
		}];
	} else {
		if (handler) {
			// We need to copy the callback, because blocks are stored on the stack!
			handler = [handler copy];
		}
		[alert beginSheetModalForWindow:self.mainView.window modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:completionHandler:) contextInfo:handler];
	}
}

- (void)alertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode completionHandler:(void (^)(NSModalResponse returnCode))handler {
	if (handler) {
		handler(returnCode);
		[handler release];
	}
}



@end



