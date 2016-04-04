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
@synthesize tabView=_tabView;

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



- (void)revealElementForKey:(NSString *)key {
	NSInteger index = [self.tabView indexOfTabViewItemWithIdentifier:key];
	if (index != NSNotFound) {
		[self.tabView selectTabViewItemAtIndex:index];
	}
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

- (void)showAlert:(NSString *)string, ... {
	va_list args;
	va_start(args, string);
	[self showAlert:string arguments:args completionHandler:nil];
	va_end(args);
}

- (void)showAlert:(NSString *)string
completionHandler:(void (^)(NSModalResponse returnCode))handler {
	
	[self showAlert:string arguments:nil completionHandler:handler];
}



- (NSAlert *)alert:(NSString *)string
		parameters:(NSArray *)parameters {
	
	NSMutableData *data = [NSMutableData dataWithLength:(sizeof(id) * parameters.count)];
	[parameters getObjects:(__unsafe_unretained id *)data.mutableBytes range:NSMakeRange(0, parameters.count)];
	
	return [self alert:string arguments:data.mutableBytes];
}

- (void)showAlert:(NSString *)string
	   parameters:(NSArray *)parameters
completionHandler:(void (^)(NSModalResponse returnCode))handler {
	
	[self displayAlert:[self alert:string parameters:parameters] completionHandler:handler];
}


- (NSAlert *)alert:(NSString *)string
		 arguments:(va_list)arguments {
	
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
	
	NSString *template = [string stringByAppendingString:@"_Checkbox"];
	NSString *checkbox = [self localizedString:template];
	if ([checkbox isEqualToString:template]) {
		checkbox = nil;
	}

	return [self alertWithTitle:title message:message buttons:buttons checkbox:checkbox];
}

- (void)showAlert:(NSString *)string
		arguments:(va_list)arguments
completionHandler:(void (^)(NSModalResponse returnCode))handler {
	
	[self displayAlert:[self alert:string arguments:arguments] completionHandler:handler];
}


- (NSAlert *)alertWithTitle:(NSString *)title
					message:(NSString *)msg
					buttons:(NSArray *)buttons
				   checkbox:(NSString *)checkbox {
	
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
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
	if (checkbox) {
		alert.showsSuppressionButton = YES;
		alert.suppressionButton.title = checkbox;
	}
	
	return alert;
}

- (void)showAlertWithTitle:(NSString *)title
				   message:(NSString *)msg
				   buttons:(NSArray *)buttons
				  checkbox:(NSString *)checkbox
		 completionHandler:(void (^)(NSModalResponse returnCode))handler {
	
	[self displayAlert:[self alertWithTitle:title message:msg buttons:buttons checkbox:checkbox] completionHandler:handler];
}





- (void)displayAlert:(NSAlert *)alert
   completionHandler:(void (^)(NSModalResponse returnCode))handler {
	
	if (NSAppKitVersionNumber >= NSAppKitVersionNumber10_9) {
		[alert beginSheetModalForWindow:self.mainView.window completionHandler:^(NSModalResponse returnCode) {
			if (handler) {
				if (alert.showsSuppressionButton && alert.suppressionButton.state == NSOnState) {
					returnCode |= 0x800;
				}
				handler(returnCode);
			}
		}];
	} else {
		NSDictionary *context = nil;
		if (handler) {
			// We need to copy the callback, because blocks are stored on the stack!
			handler = [[handler copy] autorelease];
			context = @{@"handler": handler, @"alert": alert};
		}
		[alert beginSheetModalForWindow:self.mainView.window modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:completionHandler:) contextInfo:context];
	}
}


- (void)alertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode completionHandler:(NSDictionary *)context {
	if (context) {
		void (^handler)(NSModalResponse returnCode) = context[@"handler"];
		NSAlert *alert = context[@"alert"];
		if (alert.showsSuppressionButton && alert.suppressionButton.state == NSOnState) {
			returnCode |= 0x800;
		}
		handler(returnCode);
	}
}



@end



