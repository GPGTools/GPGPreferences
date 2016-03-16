//
//  GPGReportController.m
//  GPGPreferences
//
//  Created by Mento on 14.03.16.
//  Copyright (c) 2016 GPGTools. All rights reserved.
//

#import "GPGReportController.h"
#import "GPGDebugCollector.h"
#import "GPGToolsPref.h"



@implementation GPGReportController
@synthesize username=_username, email=_email, subject=_subject, attachDebugLog=_attachDebugLog,
bugDescription=_bugDescription, expectedBahavior=_expectedBahavior, additionalInfo=_additionalInfo,
affectedComponent=_affectedComponent;




- (void)sendSupportRequest {
	NSCharacterSet *whitespaceSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
	
	
	NSString *username = [self.username stringByTrimmingCharactersInSet:whitespaceSet];
	NSString *email = [self.email stringByTrimmingCharactersInSet:whitespaceSet];
	NSString *subject = [self.subject stringByTrimmingCharactersInSet:whitespaceSet];
	NSString *bugDescription = [self.bugDescription.string stringByTrimmingCharactersInSet:whitespaceSet];
	NSString *expectedBahavior = [self.expectedBahavior.string stringByTrimmingCharactersInSet:whitespaceSet];
	NSString *additionalInfo = [self.additionalInfo.string stringByTrimmingCharactersInSet:whitespaceSet];
	BOOL privateDiscussion = self.privateDiscussion;
	
	
	// Compose the message text.
	NSMutableString *message = [NSMutableString string];
	if (self.affectedComponent > 0 && self.affectedComponent <= 5) {
		NSArray *components = @[@"GPGMail", @"GPG Keychain", @"MacGPG2", @"GPGServices", @"GPGPreferences"];
		NSString *component = components[self.affectedComponent - 1];
		
		[message appendFormat:@"**Affected Component**  \n%@\n\n", component];
	}
	NSString *versionInfo = self.updateController.versionInfo;
	[message appendFormat:@"**Problem**  \n%@\n\n", bugDescription];
	[message appendFormat:@"**Expected**  \n%@\n\n", expectedBahavior];
	if (additionalInfo.length > 0) {
		[message appendFormat:@"**Additional info**  \n%@\n\n", additionalInfo];
	}
	[message appendFormat:@"**GPG Suite version info**  \n%@\n\n", versionInfo];
	
	
	// Prepare the URL Request.
	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:@"https://gpgtools.org/supportRequest.php"]];
	NSString *boundry = [NSUUID UUID].UUIDString;
	NSData *boundryData = [[NSString stringWithFormat:@"--%@\r\n", boundry] dataUsingEncoding:NSUTF8StringEncoding];
	NSMutableData *postData = [NSMutableData data];
	
	[request setHTTPMethod:@"POST"];
	[request setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundry] forHTTPHeaderField:@"Content-Type"];
	
	
	
	// Attach the debug infos.
	if (self.attachDebugLog) {
		privateDiscussion = YES;
		
		GPGDebugCollector *debugCollector = [GPGDebugCollector new];
		NSDictionary *debugInfos = [debugCollector debugInfos];
		[debugCollector release];
		
		NSData *debugData = [NSPropertyListSerialization dataWithPropertyList:debugInfos format:NSPropertyListBinaryFormat_v1_0 options:0 error:nil];
		
		[postData appendData:boundryData];
		[postData appendData:[@"Content-Disposition: form-data; name=\"file\"; filename=\"DebugInfo.plist\"\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
		[postData appendData:debugData];
		[postData appendData:[NSData dataWithBytes:"\r\n" length:2]];
	}
	
	
	// Add the different fields to the request.
	NSString *dispo1 = @"Content-Disposition: form-data; name=\"";
	NSString *dispo2 = @"\"\r\n\r\n";
	NSMutableString *fieldsString = [NSMutableString string];
	
	[fieldsString appendFormat:@"--%@\r\n", boundry];
	[fieldsString appendFormat:@"%@username%@%@\r\n--%@\r\n", dispo1, dispo2, username, boundry];
	[fieldsString appendFormat:@"%@email%@%@\r\n--%@\r\n", dispo1, dispo2, email, boundry];
	[fieldsString appendFormat:@"%@subject%@%@\r\n--%@\r\n", dispo1, dispo2, subject, boundry];
	[fieldsString appendFormat:@"%@message%@%@\r\n--%@\r\n", dispo1, dispo2, message, boundry];
	[fieldsString appendFormat:@"%@private%@%@\r\n--%@--\r\n", dispo1, dispo2, privateDiscussion ? @"1" : @"0", boundry];
	
	[postData appendData:[fieldsString dataUsingEncoding:NSUTF8StringEncoding]];
	
	
	[request setHTTPBody:postData];
	
	
	[NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
		
		// supportRequest.php returns a JSON with html_href containing the url of the created discussion.
		NSString *href = nil;
		if (data.length > 20) {
			NSDictionary *result = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
			if ([result isKindOfClass:[NSDictionary class]]) {
				href = result[@"html_href"];
				if ([href isKindOfClass:[NSString class]] && [[href substringToIndex:31] isEqualToString:@"https://gpgtools.tenderapp.com/"]) {
					if (privateDiscussion) {
						NSString *anon_token = result[@"anon_user_token"];
						if ([anon_token isKindOfClass:[NSString class]]) {
							href = [href stringByAppendingFormat:@"?anon_token=%@", anon_token];
						}
					}
				} else {
					href = nil;
				}
			}
		}
		
		
		self.uiEnabled = YES;

		if (href) {
			NSString *template = privateDiscussion ? @"Support_PrivateReportSucceeded" : @"Support_PublicReportSucceeded";
			
			[gpgPrefPane localizedAlert:template
							 parameters:@[href]
					  completionHandler:^(NSModalResponse returnCode) {
						  [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:href]];
					  }];
		} else {
			NSString *statusCode = @"-";
			if ([response respondsToSelector:@selector(statusCode)]) {
				statusCode = [NSString stringWithFormat:@"%li", [(NSHTTPURLResponse *)response statusCode]];
			}
			NSString *result = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
			NSLog(@"Send Report Failed: '%@', Error: '%@', Response: '%@'", result, connectionError, statusCode);
			
			[gpgPrefPane localizedAlert:@"Support_ReportFailed" completionHandler:^(NSModalResponse returnCode) {
				[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://gpgtools.tenderapp.com/discussion/new"]];
			}];
		}
		
	}];
}


- (IBAction)sendSupportRequest:(id)sender {
	[gpgPrefPane.mainView.window endEditingFor:nil];
	
	NSCharacterSet *whitespaceSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
	
	NSString *username = [self.username stringByTrimmingCharactersInSet:whitespaceSet];
	NSString *email = [self.email stringByTrimmingCharactersInSet:whitespaceSet];
	NSString *subject = [self.subject stringByTrimmingCharactersInSet:whitespaceSet];
	NSString *bugDescription = [self.bugDescription.string stringByTrimmingCharactersInSet:whitespaceSet];
	NSString *expectedBahavior = [self.expectedBahavior.string stringByTrimmingCharactersInSet:whitespaceSet];
	
	// Check input fields.
	if (username.length < 3) {
		localizedAlert(@"Support_NameTooShort");
		return;
	}
	if (![self checkEmail:email]) {
		localizedAlert(@"Support_MailInvalid");
		return;
	}
	if (self.affectedComponent == 0) {
		localizedAlert(@"Support_NoComponentSelected");
		return;
	}
	if (subject.length < 5) {
		localizedAlert(@"Support_SubjectTooShort");
		return;
	}
	if (bugDescription.length < 20) {
		localizedAlert(@"Support_BugDescriptionTooShort");
		return;
	}
	if (expectedBahavior.length < 3) {
		localizedAlert(@"Support_ExpectedBahaviorTooShort");
		return;
	}

	if (self.attachDebugLog) {
		[gpgPrefPane localizedAlert:@"Support_AttachLogInfo" parameters:@[] completionHandler:^(NSModalResponse returnCode) {
			self.uiEnabled = NO;
			[self performSelectorInBackground:@selector(sendSupportRequest) withObject:nil];
		}];
	} else {
		self.uiEnabled = NO;
		[self performSelectorInBackground:@selector(sendSupportRequest) withObject:nil];
	}
}


- (BOOL)checkEmail:(NSString *)email {
	if (email.length < 6) {
		return NO;
	}
	if (email.length > 254) {
		return NO;
	}
	if ([self.email hasPrefix:@"@"] || [self.email hasSuffix:@"@"] || [self.email hasSuffix:@"."]) {
		return NO;
	}
	NSArray *components = [self.email componentsSeparatedByString:@"@"];
	if (components.count != 2) {
		return NO;
	}
	if ([(NSString *)components[0] length] > 64) {
		return NO;
	}
	
	NSMutableCharacterSet *charSet = [NSMutableCharacterSet characterSetWithRange:(NSRange){128, 65408}];
	[charSet addCharactersInString:@"01234567890_-+.!#$%&'*/=?^`{|}~abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"];
	[charSet invert];
	
	if ([components[0] rangeOfCharacterFromSet:charSet].length != 0) {
		return NO;
	}
	[charSet addCharactersInString:@"+!#$%&'*/=?^`{|}~"];
	if ([components[1] rangeOfCharacterFromSet:charSet].length != 0) {
		return NO;
	}
	
	if ([self.email rangeOfString:@"@gpgtools.org"].length > 0) {
		return NO;
	}
	
	return YES;
}


- (void)setPrivateDiscussion:(BOOL)value {
	_privateDiscussion = value;
}
- (BOOL)privateDiscussion {
	return _privateDiscussion || _attachDebugLog;
}
+ (NSSet *)keyPathsForValuesAffectingPrivateDiscussion {
	return [NSSet setWithObjects:@"attachDebugLog", nil];
}


- (void)setUiEnabled:(BOOL)value {
	_uiEnabled = value;
	if (value) {
		[self.progressSpinner stopAnimation:nil];
	} else {
		[self.progressSpinner startAnimation:nil];
	}
}
- (BOOL)uiEnabled {
	return _uiEnabled;
}


- (instancetype)init {
	self = [super init];
	if (!self) {
		return nil;
	}
	
	_uiEnabled = YES;
	
	return self;
}


// NSTextView Delegate
- (BOOL)textView:(NSTextView *)textView doCommandBySelector:(SEL)selector {
	if (selector == @selector(insertTab:)) {
		[textView.window selectNextKeyView:nil];
		return YES;
	} else if (selector == @selector(insertBacktab:)) {
		[textView.window selectPreviousKeyView:nil];
		return YES;
	}
	return NO;
}




@end
