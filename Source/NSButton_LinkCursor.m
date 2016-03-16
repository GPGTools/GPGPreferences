//
//  NSButton_LinkCursor.m
//  GPGPreferences
//
//  Created by Mento on 14.05.14.
//  Copyright (c) 2016 GPGTools. All rights reserved.
//

#import "NSButton_LinkCursor.h"

@implementation NSButton_LinkCursor
- (void)resetCursorRects {
	[self addCursorRect:[self bounds] cursor:[NSCursor pointingHandCursor]];
}
@end
