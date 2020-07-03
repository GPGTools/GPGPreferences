//
//  GPGReportController.m
//  GPGPreferences
//
//  Created by Mento on 14.03.16.
//  Copyright (c) 2016 GPGTools. All rights reserved.
//

#if !__has_feature(objc_arc)
#error This files requires ARC.
#endif


#import <Libmacgpg/GPGTaskHelperXPC.h>

#import "GPGReportController.h"
#import "GPGDebugCollector.h"
#import "GPGToolsPref.h"
#import "GPGToolsPrefController.h"
#import "GPGPVersionInfo.h"

#import "GMSupportPlanManager.h"
#import "GMSupportPlan.h"
#import "GMSPCommon.h"


static NSString * const SavedUsernameKey = @"savedReport-username";
static NSString * const SavedEmailKey = @"savedReport-email";
static NSString * const SavedAffectedComponentKey = @"savedReport-affectedComponent";
static NSString * const SavedSubjectKey = @"savedReport-subject";
static NSString * const SavedBugDescriptionKey = @"savedReport-bugDescription";
static NSString * const SavedExpectedBahaviorKey = @"savedReport-expectedBahavior";
static NSString * const SavedAdditionalInfoKey = @"savedReport-additionalInfo";
static NSString * const SavedAttachDebugLogKey = @"savedReport-attachDebugLog";
static NSString * const SavedPrivateDiscussionKey = @"savedReport-privateDiscussion";



@implementation GPGReportController


- (void)selectTool:(NSString *)tool {
	NSArray *tools = @[@"n/a", @"gpgmail", @"gpgkeychain", @"gpgservices", @"macgpg", @"gpgpreferences"];
	NSUInteger index = [tools indexOfObject:tool];
	if (index == NSNotFound) {
		index = 0;
	}
	self.affectedComponent = index;
}

- (void)sendSupportRequest {
	NSCharacterSet *whitespaceSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
	
	
	NSString *username = [self.username stringByTrimmingCharactersInSet:whitespaceSet];
	NSString *email = [self.email stringByTrimmingCharactersInSet:whitespaceSet];
	NSString *subject = [self.subject stringByTrimmingCharactersInSet:whitespaceSet];
	NSString *bugDescription = [self.bugDescription stringByTrimmingCharactersInSet:whitespaceSet];
	NSString *expectedBahavior = [self.expectedBahavior stringByTrimmingCharactersInSet:whitespaceSet];
	NSString *additionalInfo = [self.additionalInfo stringByTrimmingCharactersInSet:whitespaceSet];
	BOOL privateDiscussion = self.privateDiscussion;
	
	
	// Compose the message text.
	NSMutableString *message = [NSMutableString string];
	if (self.affectedComponent > 0 && self.affectedComponent <= 5) {
		NSArray *components = @[@"GPG Mail", @"GPG Keychain", @"GPG Services", @"MacGPG", @"GPG Suite Preferences"];
		NSString *component = components[self.affectedComponent - 1];
		
		subject = [NSString stringWithFormat:@"%@: %@", component, subject];
	}
	[message appendFormat:@"%@\n\n", bugDescription];
	[message appendFormat:@"**Expected**  \n%@\n\n", expectedBahavior];
	if (additionalInfo.length > 0) {
		[message appendFormat:@"**Additional info**  \n%@\n\n", additionalInfo];
	}
	NSString *versionInfo = _versionInfo.versionInfo;
	[message appendFormat:@"\n```\n%@```\n\n", versionInfo];
	
	
	// Prepare the URL Request.
	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:@"https://gpgtools.org/supportRequest.php"]];
	NSString *boundry = [NSUUID UUID].UUIDString;
	NSData *boundryData = [[NSString stringWithFormat:@"--%@\r\n", boundry] dataUsingEncoding:NSUTF8StringEncoding];
	NSMutableData *postData = [NSMutableData data];
	
	[request setHTTPMethod:@"POST"];
	[request setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundry] forHTTPHeaderField:@"Content-Type"];
	
	
	
	// Attach the debug infos.
	if (self.attachDebugLog) {
		GPGDebugCollector *debugCollector = [GPGDebugCollector new];
		NSDictionary *debugInfos = [debugCollector debugInfos];
		
		NSError *error = nil;
		NSData *debugData = [NSPropertyListSerialization dataWithPropertyList:debugInfos format:NSPropertyListBinaryFormat_v1_0 options:0 error:&error];
		if (debugData.length == 0) {
			@try {
				debugData = [NSKeyedArchiver archivedDataWithRootObject:debugInfos];
			} @finally {}
		}
		if (debugData.length == 0) {
			debugData = [[NSString stringWithFormat:@"Error generating debug info: %@", error] dataUsingEncoding:NSUTF8StringEncoding];
		}
		
		
		NSDateFormatter *format = [NSDateFormatter new];
		format.dateFormat = @"yyyy-MM-dd_HH-mm";
		format.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
		NSString *filename = [NSString stringWithFormat:@"%@_DebugInfo.plist", [format stringFromDate:[NSDate date]]];
		
		[postData appendData:boundryData];
		[postData appendData:[@"Content-Disposition: form-data; name=\"file\"; filename=\"" dataUsingEncoding:NSUTF8StringEncoding]];
		[postData appendData:[filename dataUsingEncoding:NSUTF8StringEncoding]];
		[postData appendData:[@"\"\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
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
	[fieldsString appendFormat:@"%@private%@%@\r\n--%@", dispo1, dispo2, privateDiscussion ? @"1" : @"0", boundry];
	
    // Fetch support plan information if available.
	GMSupportPlanManager *manager = _versionInfo.supportPlanManager;
	if([manager supportPlanIsActive] && ![[manager supportPlan] isKindOfTrial]) {
        GMSupportPlan *supportPlan = [manager supportPlan];
        if([[manager currentActivationCode] length]) {
            [fieldsString appendFormat:@"\r\n%@support_plan_email%@%@\r\n--%@", dispo1, dispo2, [manager currentEmail], boundry];
        }
        if([[manager currentActivationCode] length]) {
            // Last field, as it ends with --
            [fieldsString appendFormat:@"\r\n%@support_plan_activation_code%@%@\r\n--%@", dispo1, dispo2, [manager currentActivationCode], boundry];
        }
		
        [fieldsString appendFormat:@"\r\n%@support_plan%@%@\r\n--%@", dispo1, dispo2, supportPlan.asData.gpgString.GMSP_base64Encode, boundry];

    }
    [fieldsString appendString:@"--\r\n"];
    
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
			// Report successfully sent.
			
			// Clear saved values.
			[_options setValue:nil forKey:SavedUsernameKey];
			[_options setValue:nil forKey:SavedEmailKey];
			[_options setValue:nil forKey:SavedAffectedComponentKey];
			[_options setValue:nil forKey:SavedSubjectKey];
			[_options setValue:nil forKey:SavedBugDescriptionKey];
			[_options setValue:nil forKey:SavedExpectedBahaviorKey];
			[_options setValue:nil forKey:SavedAdditionalInfoKey];
			[_options setValue:nil forKey:SavedAttachDebugLogKey];
			[_options setValue:nil forKey:SavedPrivateDiscussionKey];
			
			
			NSString *template = privateDiscussion ? @"Support_PrivateReportSucceeded" : @"Support_PublicReportSucceeded";
			
			[gpgPrefPane showAlert:template
						parameters:@[href]
				 completionHandler:^(NSModalResponse returnCode) {
					 [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:href]];
				 }];
		} else {
			NSString *statusCode = @"-";
			if ([response respondsToSelector:@selector(statusCode)]) {
				statusCode = [NSString stringWithFormat:@"%li", [(NSHTTPURLResponse *)response statusCode]];
			}
			NSString *result = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
			NSLog(@"Send Report Failed: '%@', Error: '%@', Response: '%@'", result, connectionError, statusCode);
			
			[gpgPrefPane showAlert:@"Support_ReportFailed"
				 completionHandler:^(NSModalResponse returnCode) {
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
	NSString *bugDescription = [self.bugDescription stringByTrimmingCharactersInSet:whitespaceSet];
	NSString *expectedBahavior = [self.expectedBahavior stringByTrimmingCharactersInSet:whitespaceSet];
	
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

	
	NSAlert *alert = [gpgPrefPane alert:@"Support_SendDebugInfo" parameters:nil];
	alert.suppressionButton.state = self.attachDebugLog ? NSOnState : NSOffState;
	
	[gpgPrefPane displayAlert:alert completionHandler:^(NSModalResponse returnCode) {
		BOOL sendLog = NO;
		if (returnCode & 0x800) {
			sendLog = YES;
			returnCode -= 0x800;
		}
		
		if (returnCode == NSAlertFirstButtonReturn || returnCode == NSAlertDefaultReturn) {
			self.uiEnabled = NO;
			self.attachDebugLog = sendLog;
			[self performSelectorInBackground:@selector(sendSupportRequest) withObject:nil];
		}
	}];
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



- (void)setUiEnabled:(BOOL)value {
	_uiEnabled = value;
	if (value) {
		[self.progressSpinner stopAnimation:nil];
	} else {
		[self.progressSpinner startAnimation:nil];
	}
}


- (instancetype)init {
	self = [super init];
	if (!self) {
		return nil;
	}
	
	_versionInfo = [GPGPVersionInfo sharedInstance];
	_uiEnabled = YES;
	
	return self;
}
- (void)awakeFromNib {
	_options = self.prefController.options;

	[self loadSavedValues];
	
	GMSupportPlanState state = _versionInfo.supportPlanManager.supportPlanState;
    if (state == GMSupportPlanStateActive) {
		// Always set discussions for users with active support plan to private.
		self.privateDiscussion = YES;
		self.privateDisabled = YES;
	}
	
	if (_username.length == 0) {
		self.username = NSFullUserName();
	}
	
	if (_email.length == 0) {
		self.email = self.prefController.crashReportsUserEmail;
	}
	[self.prefController addObserver:self forKeyPath:@"crashReportsUserEmail" options:NSKeyValueObservingOptionOld context:nil];
	
}

- (void)dealloc {
	[self.prefController removeObserver:self forKeyPath:@"crashReportsUserEmail"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
	if (object == self.prefController && [keyPath isEqualToString:@"crashReportsUserEmail"]) {
		if (self.email.length == 0 || [change[@"old"] isEqual:self.email]) {
			self.email = self.prefController.crashReportsUserEmail;
		}
	}
}


- (void)loadSavedValues {
	// Fill all the saved fields from a previous (not sent) report.
	
	NSString *stringValue;
	NSNumber *numberValue;
	
	stringValue = [_options valueForKey:SavedUsernameKey];
	if ([stringValue isKindOfClass:NSString.class]) {
		self.username = stringValue;
	}
	stringValue = [_options valueForKey:SavedEmailKey];
	if ([stringValue isKindOfClass:NSString.class]) {
		self.email = stringValue;
	}
	numberValue = [_options valueForKey:SavedAffectedComponentKey];
	if ([numberValue isKindOfClass:NSNumber.class]) {
		self.affectedComponent = numberValue.integerValue;
	}
	stringValue = [_options valueForKey:SavedSubjectKey];
	if ([stringValue isKindOfClass:NSString.class]) {
		self.subject = stringValue;
	}
	stringValue = [_options valueForKey:SavedBugDescriptionKey];
	if ([stringValue isKindOfClass:NSString.class]) {
		self.bugDescription = stringValue;
		// -ensureLayoutForCharacterRange: is required because the textview has allowsNonContiguousLayout set and a negative textContainerInset.
		// Without this, the text would not be drawn until an e.g. mouse-over event.
		[self.textView1.layoutManager ensureLayoutForCharacterRange:NSMakeRange(0, stringValue.length)];
	}
	stringValue = [_options valueForKey:SavedExpectedBahaviorKey];
	if ([stringValue isKindOfClass:NSString.class]) {
		self.expectedBahavior = stringValue;
		// -ensureLayoutForCharacterRange: is required because the textview has allowsNonContiguousLayout set and a negative textContainerInset.
		// Without this, the text would not be drawn until an e.g. mouse-over event.
		[self.textView2.layoutManager ensureLayoutForCharacterRange:NSMakeRange(0, stringValue.length)];
	}
	stringValue = [_options valueForKey:SavedAdditionalInfoKey];
	if ([stringValue isKindOfClass:NSString.class]) {
		self.additionalInfo = stringValue;
		// -ensureLayoutForCharacterRange: is required because the textview has allowsNonContiguousLayout set and a negative textContainerInset.
		// Without this, the text would not be drawn until an e.g. mouse-over event.
		[self.textView3.layoutManager ensureLayoutForCharacterRange:NSMakeRange(0, stringValue.length)];
	}
	numberValue = [_options valueForKey:SavedAttachDebugLogKey];
	if ([numberValue isKindOfClass:NSNumber.class]) {
		self.attachDebugLog = numberValue.boolValue;
	}
	numberValue = [_options valueForKey:SavedPrivateDiscussionKey];
	if ([numberValue isKindOfClass:NSNumber.class]) {
		self.privateDiscussion = numberValue.boolValue;
	}
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



- (NSAttributedString *)attributedVersions {
	return _versionInfo.attributedVersions;
}


#pragma mark Getters and setters for user entered information.

- (void)setUsername:(NSString *)username {
	if (username != _username) {
		_username = username;
		[_options setValue:username forKey:SavedUsernameKey];
	}
}
- (void)setEmail:(NSString *)email {
	if (email != _email) {
		_email = email;
		[_options setValue:email forKey:SavedEmailKey];
	}
}
- (void)setAffectedComponent:(NSInteger)affectedComponent {
	if (affectedComponent != _affectedComponent) {
		_affectedComponent = affectedComponent;
		[_options setValue:@(affectedComponent) forKey:SavedAffectedComponentKey];
	}
}
- (void)setSubject:(NSString *)subject {
	if (subject != _subject) {
		_subject = subject;
		[_options setValue:subject forKey:SavedSubjectKey];
	}
}
- (void)setBugDescription:(NSString *)bugDescription {
 	if (bugDescription != _bugDescription) {
		_bugDescription = bugDescription;
		[_options setValue:bugDescription forKey:SavedBugDescriptionKey];
	}
}
- (void)setExpectedBahavior:(NSString *)expectedBahavior {
	if (expectedBahavior != _expectedBahavior) {
		_expectedBahavior = expectedBahavior;
		[_options setValue:expectedBahavior forKey:SavedExpectedBahaviorKey];
	}
}
- (void)setAdditionalInfo:(NSString *)additionalInfo {
	if (additionalInfo != _additionalInfo) {
		_additionalInfo = additionalInfo;
		[_options setValue:additionalInfo forKey:SavedAdditionalInfoKey];
	}
}
- (void)setAttachDebugLog:(BOOL)attachDebugLog {
	if (attachDebugLog != _attachDebugLog) {
		_attachDebugLog = attachDebugLog;
		[_options setValue:@(attachDebugLog) forKey:SavedAttachDebugLogKey];
	}
}
- (void)setPrivateDiscussion:(BOOL)privateDiscussion {
	if (privateDiscussion != _privateDiscussion) {
		_privateDiscussion = privateDiscussion;
		[_options setValue:@(privateDiscussion) forKey:SavedPrivateDiscussionKey];
	}
}



#pragma mark TextView styling.

- (NSFont *)textViewFont {
	return [NSFont systemFontOfSize:[NSFont systemFontSize]];
}
- (NSColor *)textViewFontColor {
	return [NSColor textColor];
}
- (void)setTextView1:(NSTextView *)value {
	_textView1 = value;
	if (value) {
		[value setTextContainerInset:NSMakeSize(-2, 0)];
	}
}
- (void)setTextView2:(NSTextView *)value {
	_textView2 = value;
	if (value) {
		[value setTextContainerInset:NSMakeSize(-2, 0)];
	}
}
- (void)setTextView3:(NSTextView *)value {
	_textView3 = value;
	if (value) {
		[value setTextContainerInset:NSMakeSize(-2, 0)];
	}
}



@end
