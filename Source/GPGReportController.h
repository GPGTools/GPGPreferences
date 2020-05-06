//
//  GPGReportController.h
//  GPGPreferences
//
//  Created by Mento on 14.03.16.
//  Copyright (c) 2016 GPGTools. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Libmacgpg/Libmacgpg.h>

@class GPGToolsPrefController;

@interface GPGReportController : NSObject <NSTextViewDelegate> {
	GPGOptions *_options;
}

@property (nonatomic, strong) NSString *username;
@property (nonatomic, strong) NSString *email;
@property (nonatomic, strong) NSString *subject;
@property (nonatomic, strong) NSString *bugDescription;
@property (nonatomic, strong) NSString *expectedBahavior;
@property (nonatomic, strong) NSString *additionalInfo;
@property (nonatomic) BOOL attachDebugLog;
@property (nonatomic) BOOL privateDiscussion;
@property (nonatomic) BOOL privateDisabled;
@property (nonatomic) NSInteger affectedComponent;
@property (nonatomic) BOOL uiEnabled;
@property (nonatomic, assign) IBOutlet NSProgressIndicator *progressSpinner;

@property (nonatomic, assign) IBOutlet NSTextView *textView1;
@property (nonatomic, assign) IBOutlet NSTextView *textView2;
@property (nonatomic, assign) IBOutlet NSTextView *textView3;
@property (nonatomic, assign) IBOutlet GPGToolsPrefController *prefController;

- (void)selectTool:(NSString *)tool;


@end
