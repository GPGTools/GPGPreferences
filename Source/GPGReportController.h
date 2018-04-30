//
//  GPGReportController.h
//  GPGPreferences
//
//  Created by Mento on 14.03.16.
//  Copyright (c) 2016 GPGTools. All rights reserved.
//

#import <Foundation/Foundation.h>

@class GPGToolsPrefController;

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
	id _textView1, _textView2, _textView3;
}

@property (nonatomic, strong) NSString *username;
@property (nonatomic, strong) NSString *email;
@property (nonatomic, strong) NSString *subject;
@property (nonatomic, strong) NSAttributedString *bugDescription;
@property (nonatomic, strong) NSAttributedString *expectedBahavior;
@property (nonatomic, strong) NSAttributedString *additionalInfo;
@property (nonatomic) BOOL attachDebugLog;
@property (nonatomic) BOOL privateDiscussion;
@property (nonatomic) NSInteger affectedComponent;
@property (nonatomic) BOOL uiEnabled;
@property (nonatomic, assign) IBOutlet NSProgressIndicator *progressSpinner;

@property (nonatomic, assign) IBOutlet NSTextView *textView1;
@property (nonatomic, assign) IBOutlet NSTextView *textView2;
@property (nonatomic, assign) IBOutlet NSTextView *textView3;
@property (nonatomic, assign) IBOutlet GPGToolsPrefController *prefController;

@end
