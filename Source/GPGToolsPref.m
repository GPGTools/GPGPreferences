//
//  GPGToolsPref.m
//  GPGTools
//
//  Created by Alexander Willner on 04.08.10.
//  Copyright © 2019 GPGTools. All rights reserved.
//

#import "GPGToolsPref.h"
#import <Libmacgpg/Libmacgpg.h>

GPGToolsPref *gpgPrefPane = nil;

static NSString * const GPGPreferencesShowTabNotification = @"GPGPreferencesShowTabNotification";


@implementation NSString (stringWithFormat_parameters)

+ (instancetype)stringWithFormat:(NSString *)format parameters:(NSArray *)parameters {
	// Based on code from http://stackoverflow.com/questions/35039383 http://stackoverflow.com/users/4759124/ajjnix
	
	// https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html
	NSInteger sizeptr = sizeof(void *);
	NSInteger sumArgInvoke = parameters.count + 3; //self + _cmd + (NSString *)format
	NSInteger offsetReturnType = sumArgInvoke * sizeptr;
	
	NSMutableString *mstring = [[[NSMutableString alloc] init] autorelease];
	[mstring appendFormat:@"@%zd@0:%zd", offsetReturnType, sizeptr];
	for (NSInteger i = 2; i < sumArgInvoke; i++) {
		[mstring appendFormat:@"@%zd", sizeptr * i];
	}
	NSMethodSignature *methodSignature = [NSMethodSignature signatureWithObjCTypes:[mstring UTF8String]];

	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:methodSignature];
	
	invocation.target = self;
	invocation.selector = @selector(stringWithFormat:);
	
	[invocation setArgument:&format atIndex:2];
	for (NSInteger i = 0; i < [parameters count]; i++) {
		id obj = parameters[i];
		[invocation setArgument:(&obj) atIndex:i+3];
	}
	
	[invocation invoke];
	
	__autoreleasing NSString *string;
	[invocation getReturnValue:&string];
	
	return string;
}

@end




@implementation GPGToolsPref
@synthesize tabView=_tabView;

- (instancetype)initWithBundle:(NSBundle *)bundle {
	self = [super initWithBundle:bundle];
	if (self == nil) {
		return nil;
	}
	gpgPrefPane = [self retain];

	[[NSDistributedNotificationCenter defaultCenter] addObserver:self
														selector:@selector(showTabNotificaiton:)
															name:GPGPreferencesShowTabNotification
														  object:nil
											  suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];
	
	if ([bundle respondsToSelector:@selector(useGPGLocalizations)]) {
		[bundle useGPGLocalizations];
	}
	
	
	
	// System Preferences.app has a nice "x-apple.systempreferences:" url scheme, with support to select the tab to show.
	// Example: open "x-apple.systempreferences:com.apple.preference.security?Firewall"
	// BUT this only works for preference panes which are signed by Apple and have NSPrefPaneAllowsXAppleSystemPreferencesURLScheme = YES in their Info.plist
	//
	// So this a solution to launch GPGPreferences with a specific tab shown.
	self.infoToShow = [GPGTask readGPGSuitePreferencesArguments];
	
	
	return self;
}

- (void)dealloc {
	[[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
	self.infoToShow = nil;
	[super dealloc];
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


- (void)showTabNotificaiton:(NSNotification *)notification {
	[self revealElementWithInfo:notification.userInfo];
	
	// Remove the temporary file, which contains the tab to show.
	[GPGTask readGPGSuitePreferencesArguments];
}




- (void)willUnselect {
	[self.mainView.window makeFirstResponder:nil];
}


- (void)revealElementWithInfo:(NSDictionary *)userInfo {
	if (_viewsLoaded) {
		NSString *tabName = userInfo[@"tab"];
		if (tabName) {
			NSInteger index = [self.tabView indexOfTabViewItemWithIdentifier:tabName];
			if (index != NSNotFound) {
				[self.tabView selectTabViewItemAtIndex:index];
			}
		}
		NSString *tool = userInfo[@"tool"];
		if (tool) {
			GPGReportController *reportController = self.reportController;
			[reportController selectTool:tool];
		}
		
	} else {
		self.infoToShow = userInfo;
	}
}

- (void)revealElementForKey:(NSString *)key {
	[self revealElementWithInfo:@{@"tab": key}];
}
- (void)mainViewDidLoad {
	_viewsLoaded = YES;
	if (self.infoToShow) {
		[self revealElementWithInfo:self.infoToShow];
		self.infoToShow = nil;
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



#pragma mark Alerts


// Show alerts.

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


- (void)showAlert:(NSString *)string
	   parameters:(NSArray *)parameters
completionHandler:(void (^)(NSModalResponse returnCode))handler {
	
	[self displayAlert:[self alert:string parameters:parameters] completionHandler:handler];
}


- (void)showAlert:(NSString *)string
		arguments:(va_list)arguments
completionHandler:(void (^)(NSModalResponse returnCode))handler {
	
	[self displayAlert:[self alert:string arguments:arguments] completionHandler:handler];
}


- (void)showAlertWithTitle:(NSString *)title
				   message:(NSString *)msg
				   buttons:(NSArray *)buttons
				  checkbox:(NSString *)checkbox
		 completionHandler:(void (^)(NSModalResponse returnCode))handler {
	
	[self displayAlert:[self alertWithTitle:title message:msg buttons:buttons checkbox:checkbox] completionHandler:handler];
}



// Create alerts.

- (NSAlert *)alert:(NSString *)string
		 arguments:(va_list)arguments {
	
	NSString *messageFormat = [self localizedString:[string stringByAppendingString:@"_Msg"]];
	NSString *message;
	if (arguments) {
		message = [[[NSString alloc] initWithFormat:messageFormat arguments:arguments] autorelease];
	} else {
		message = messageFormat;
	}
	
	return [self alert:string message:message];
}


- (NSAlert *)alert:(NSString *)string
		parameters:(NSArray *)parameters {
	
	NSString *messageFormat = [self localizedString:[string stringByAppendingString:@"_Msg"]];
	NSString *message;
	if (parameters) {
		message = [NSString stringWithFormat:messageFormat parameters:parameters];
	} else {
		message = messageFormat;
	}
	
	return [self alert:string message:message];
}

- (NSAlert *)alert:(NSString *)string
		   message:(NSString *)message {
	
	NSString *title = [self localizedString:[string stringByAppendingString:@"_Title"]];
	
	
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


// Dispaly alerts.
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


// Alert end.
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



