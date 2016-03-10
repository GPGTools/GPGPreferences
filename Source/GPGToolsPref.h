//
//  GPGToolsPref.h
//  GPGTools
//
//  Created by Alexander Willner on 04.08.10.
//  Copyright (c) 2010 GPGTools Project Team. All rights reserved.
//

#import <PreferencePanes/PreferencePanes.h>

@class GPGToolsPref;
extern GPGToolsPref *gpgToolsPrefPane;

#define localized(string) [gpgToolsPrefPane.bundle localizedStringForKey:string value:nil table:nil]


@interface GPGToolsPref : NSPreferencePane
- (void)panelWithTitle:(NSString *)title message:(NSString *)msg;
@end
