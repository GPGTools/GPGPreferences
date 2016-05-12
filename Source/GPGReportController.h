//
//  GPGReportController.h
//  GPGPreferences
//
//  Created by Mento on 14.03.16.
//  Copyright (c) 2016 GPGTools. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GPGReportController : NSObject <NSTextViewDelegate> {
	NSString *_username;
	NSString *_email;
	NSString *_subject;
	NSAttributedString *_bugDescription;
	NSAttributedString *_expectedBahavior;
	NSAttributedString *_additionalInfo;
	BOOL _attachDebugLog;
	BOOL _privateDiscussion;
	NSInteger _affectedComponent;
	BOOL _uiEnabled;
	NSProgressIndicator *_progressSpinner;
}

@property (strong) NSString *username;
@property (strong) NSString *email;
@property (strong) NSString *subject;
@property (strong) NSAttributedString *bugDescription;
@property (strong) NSAttributedString *expectedBahavior;
@property (strong) NSAttributedString *additionalInfo;
@property BOOL attachDebugLog;
@property BOOL privateDiscussion;
@property NSInteger affectedComponent;
@property BOOL uiEnabled;
@property (assign) IBOutlet NSProgressIndicator *progressSpinner;

@end
