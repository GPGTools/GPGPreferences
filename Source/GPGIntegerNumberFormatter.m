//
//  GPGIntNumberFormatter.m
//  GPGPreferences
//
//  Created by Mento on 16/05/2017.
//  Copyright © 2017 GPGTools. All rights reserved.
//

#import "GPGIntegerNumberFormatter.h"

@implementation GPGIntegerNumberFormatter


- (BOOL)isPartialStringValid:(NSString **)partialStringPtr
	   proposedSelectedRange:(NSRangePointer)proposedSelRangePtr
			  originalString:(NSString *)origString
	   originalSelectedRange:(NSRange)origSelRange
			errorDescription:(NSString **)error {
	
	NSString *partialString = *partialStringPtr;
	NSUInteger maxLength = self.maximum.stringValue.length;
	
	if (partialString.length == 0) {
		return YES;
	}
	
	NSCharacterSet *nonDigitSet = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
	
	if ([partialString rangeOfCharacterFromSet:nonDigitSet].length == 0) {
		NSScanner *scanner = [NSScanner scannerWithString:partialString];
		unsigned long long value;
		if ([scanner scanUnsignedLongLong:&value] && [scanner isAtEnd]) {
			
			if (partialString.length > maxLength) {
				if (origString.length < maxLength) {
					*partialStringPtr = [partialString substringToIndex:maxLength];
				}
				NSBeep();
				return NO;
			}
			
			if (value <= self.maximum.unsignedIntegerValue) {
				return YES;
			}
		}
	}
	
	NSBeep();
	return NO;
}

@end
