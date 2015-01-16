//
//  GPGToolsPref.h
//  GPGTools
//
//  Created by Alexander Willner on 04.08.10.
//  Copyright (c) 2010 GPGTools Project Team. All rights reserved.
//

#import <PreferencePanes/PreferencePanes.h>

extern NSBundle *gpgPreferencesBundle;

void WarningPanel(NSString *title, NSString *msg);

#define localized(string) [gpgPreferencesBundle localizedStringForKey:string value:nil table:nil]


@interface GPGToolsPref : NSPreferencePane
@end
