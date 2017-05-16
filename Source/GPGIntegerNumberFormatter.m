//
//  GPGIntNumberFormatter.m
//  GPGPreferences
//
//  Created by Mento on 16/05/2017.
//  Copyright © 2017 GPGTools. All rights reserved.
//

#import "GPGIntegerNumberFormatter.h"

@implementation GPGIntegerNumberFormatter


- (BOOL)isPartialStringValid:(NSString *)partialString newEditingString:(NSString **)newString errorDescription:(NSString **)error {
	if (partialString.length == 0) {
		return YES;
	}
	
	NSCharacterSet *nonDigitSet = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
	if ([partialString rangeOfCharacterFromSet:nonDigitSet].length > 0) {
		NSBeep();
		return NO;
	}
	
	NSScanner *scanner = [NSScanner scannerWithString:partialString];
	unsigned long long value;
	
	if ([scanner scanUnsignedLongLong:&value] && [scanner isAtEnd]) {
		if (value > self.maximum.integerValue) {
			*newString = self.maximum.stringValue;
			if (value >= self.maximum.integerValue * 10) {
				NSBeep();
			}
			return NO;
		}
		if (partialString.length <= 5) {
			return YES;
		}
	}
	
	NSBeep();
	return NO;
}

@end
