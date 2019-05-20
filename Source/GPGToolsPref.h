//
//  GPGToolsPref.h
//  GPGTools
//
//  Created by Alexander Willner on 04.08.10.
//  Copyright (c) 2016 GPGTools Project Team. All rights reserved.
//

#import <PreferencePanes/PreferencePanes.h>
#import "GPGReportController.h"

@class GPGToolsPref;
extern GPGToolsPref *gpgPrefPane;

#define localizedAlert(...) [gpgPrefPane showAlert:__VA_ARGS__]

#define localized(string) [gpgPrefPane localizedString:string]


@interface GPGToolsPref : NSPreferencePane {
	NSTabView *_tabView;
	BOOL _viewsLoaded;
}

@property (nonatomic, assign) IBOutlet GPGReportController *reportController;
@property (nonatomic, copy) NSDictionary *infoToShow;
@property (nonatomic, strong) IBOutlet NSTabView *tabView;

- (NSString *)localizedString:(NSString *)key;


// The -(void)showAlert* methods create and display an alert.
// The -(NSAlert *)alert methods only create the alert.
// Use displayAlert to display a created alert.
//
// The methods with the "string" argument create a localized alert,
//  based on the template "string". See Localizable.strings.
// The returnCode is ORed with 0x800 when the checkbox is enabled.
- (void)showAlert:(NSString *)string, ...;
- (void)showAlert:(NSString *)string
completionHandler:(void (^)(NSModalResponse returnCode))handler;
- (NSAlert *)alert:(NSString *)string
		parameters:(NSArray *)parameters;
- (void)showAlert:(NSString *)string
	   parameters:(NSArray *)parameters
completionHandler:(void (^)(NSModalResponse returnCode))handler;
- (NSAlert *)alert:(NSString *)string
		 arguments:(va_list)arguments;
- (void)showAlert:(NSString *)string
		arguments:(va_list)arguments
completionHandler:(void (^)(NSModalResponse returnCode))handler;
- (NSAlert *)alertWithTitle:(NSString *)title
					message:(NSString *)msg
					buttons:(NSArray *)buttons
				   checkbox:(NSString *)checkbox;
- (void)showAlertWithTitle:(NSString *)title
				   message:(NSString *)msg
				   buttons:(NSArray *)buttons
				  checkbox:(NSString *)checkbox
		 completionHandler:(void (^)(NSModalResponse returnCode))handler;
- (void)displayAlert:(NSAlert *)alert
   completionHandler:(void (^)(NSModalResponse returnCode))handler;

@end
