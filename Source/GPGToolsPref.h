//
//  GPGToolsPref.h
//  GPGTools
//
//  Created by Alexander Willner on 04.08.10.
//  Copyright (c) 2016 GPGTools Project Team. All rights reserved.
//

#import <PreferencePanes/PreferencePanes.h>

@class GPGToolsPref;
extern GPGToolsPref *gpgPrefPane;

#define localizedAlert(...) [gpgPrefPane localizedAlert:__VA_ARGS__]

#define localized(string) [gpgPrefPane localizedString:string]


@interface GPGToolsPref : NSPreferencePane
- (NSString *)localizedString:(NSString *)key;
- (void)localizedAlert:(NSString *)string, ...;
- (void)localizedAlert:(NSString *)string
	 completionHandler:(void (^)(NSModalResponse returnCode))handler;
- (void)localizedAlert:(NSString *)string
			parameters:(NSArray *)parameters
	 completionHandler:(void (^)(NSModalResponse returnCode))handler;
- (void)localizedAlert:(NSString *)string
			 arguments:(va_list)arguments
	 completionHandler:(void (^)(NSModalResponse returnCode))handler;
- (void)alertWithTitle:(NSString *)title
			   message:(NSString *)msg
			   buttons:(NSArray *)buttons
	 completionHandler:(void (^)(NSModalResponse returnCode))handler;
@end
