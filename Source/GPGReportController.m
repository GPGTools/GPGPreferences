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
#import "GPGToolsPrefController.h"



@interface NSString (PadWithTabs)
- (NSString *)stringByPaddingToTab:(NSUInteger)tab;
@end
@implementation NSString (PadWithTabs)
- (NSString *)stringByPaddingToTab:(NSUInteger)tab {
	NSUInteger length = self.length;
	return [self stringByPaddingToLength:length + tab - (length / 4) withString:@"\t" startingAtIndex:0];
}
@end


@implementation GPGReportController
@synthesize username=_username, email=_email, subject=_subject, attachDebugLog=_attachDebugLog,
bugDescription=_bugDescription, expectedBahavior=_expectedBahavior, additionalInfo=_additionalInfo,
affectedComponent=_affectedComponent, privateDiscussion=_privateDiscussion;




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
		NSArray *components = @[@"GPGMail", @"GPG Keychain", @"MacGPG", @"GPGServices", @"GPG Suite Preferences"];
		NSString *component = components[self.affectedComponent - 1];
		
		subject = [NSString stringWithFormat:@"%@: %@", component, subject];
	}
	[message appendFormat:@"%@\n\n", bugDescription];
	[message appendFormat:@"**Expected**  \n%@\n\n", expectedBahavior];
	if (additionalInfo.length > 0) {
		[message appendFormat:@"**Additional info**  \n%@\n\n", additionalInfo];
	}
	NSString *versionInfo = self.versionInfo;
	[message appendFormat:@"%@\n\n", versionInfo];
	
	
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
		[debugCollector release];
		
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
			NSString *result = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
			NSLog(@"Send Report Failed: '%@', Error: '%@', Response: '%@'", result, connectionError, statusCode);
			
			[gpgPrefPane showAlert:@"Support_ReportFailed"
				 completionHandler:^(NSModalResponse returnCode) {
				[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://gpgtools.tenderapp.com/discussion/new"]];
			}];
		}
		
	}];
}


- (IBAction)sendSupportRequest:(id)sender {
	NSLog(@"%@", self.versionInfo);
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
- (void)awakeFromNib {
	self.email = self.prefController.crashReportsUserEmail;
	[self.prefController addObserver:self forKeyPath:@"crashReportsUserEmail" options:NSKeyValueObservingOptionOld context:nil];
}
- (void)dealloc {
	[self.prefController removeObserver:self forKeyPath:@"crashReportsUserEmail"];
	[super dealloc];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
	if (object == self.prefController && [keyPath isEqualToString:@"crashReportsUserEmail"]) {
		if (self.email.length == 0 || [change[@"old"] isEqual:self.email]) {
			self.email = self.prefController.crashReportsUserEmail;
		}
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


- (NSArray *)toolVersions {
#define PKEY @"path"
#define IKEY @"identifier"
#define NKEY @"toolname"
#define LKEY @"plist"
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSDictionary *systemPlist = [NSDictionary dictionaryWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"];
	NSArray *tools = @[
					   @{NKEY: @"GPG Suite",
						 PKEY: @[@"/Library/Application Support/GPGTools/GPGSuite_Updater.app"]},

					   @{NKEY: @"GPGMail",
						 PKEY: @[@"/Network/Library/Mail/Bundles/GPGMail.mailbundle", @"~/Library/Mail/Bundles/GPGMail.mailbundle", @"/Library/Mail/Bundles/GPGMail.mailbundle"]},
					   
					   @{NKEY: @"GPG Keychain",
						 IKEY: @"org.gpgtools.gpgkeychain"},
					   
					   @{NKEY: @"GPGServices",
						 PKEY: @[@"~/Library/Services/GPGServices.service", @"/Library/Services/GPGServices.service"]},
					   
					   @{NKEY: @"MacGPG",
						 PKEY: @"/usr/local/MacGPG2",
						 LKEY: @"share/gnupg/Version.plist"},
					   
					   @{NKEY: @"GPG Suite Preferences",
						 PKEY: @[@"~/Library/PreferencePanes/GPGPreferences.prefPane", @"/Library/PreferencePanes/GPGPreferences.prefPane"]},
					   
					   @{NKEY: @"Libmacgpg",
						 PKEY: @[@"~/Library/Frameworks/Libmacgpg.framework", @"/Library/Frameworks/Libmacgpg.framework"],
						 LKEY: @"Resources/Info.plist"},
					   
					   @{NKEY: @"pinentry",
						 PKEY: @[@"/usr/local/MacGPG2/libexec/pinentry-mac.app"]}
					   ];
	
	
	NSMutableArray *versions = [NSMutableArray array];

	
	NSString *osVersion = [systemPlist objectForKey:@"ProductVersion"];
	NSString *part = [osVersion substringToIndex:5];
	NSString *osName = @"macOS";
	
	if ([part isEqualToString:@"10.9."] || [part isEqualToString:@"10.10."] || [part isEqualToString:@"10.11."]) {
		osName = @"Mac OS X";
	}
	
	[versions addObject:@{@"name": osName,
						  @"version": [systemPlist objectForKey:@"ProductVersion"],
						  @"build": [systemPlist objectForKey:@"ProductBuildVersion"],
						  @"commit": @""}];
	
	
	
	for (NSDictionary *toolInfo in tools) {
	
		// Readable name of the tool.
		NSString *name = toolInfo[NKEY];

		// Possible paths to the tool.
		id paths = [toolInfo objectForKey:PKEY];
		if (!paths) {
			NSString *path = [[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier:toolInfo[IKEY]];
			paths = path ? @[path] : @[];
		} else if (![paths isKindOfClass:[NSArray class]]) {
			paths = @[paths];
		}
		
		// Content of Info.plist
		NSDictionary *infoPlist = nil;
		for (NSString *path in paths) {
			path = [path stringByExpandingTildeInPath];
			NSString *plistPath = toolInfo[LKEY];
			if (!plistPath) {
				plistPath = @"Contents/Info.plist";
			}
			plistPath = [path stringByAppendingPathComponent:plistPath];
			if ([fileManager fileExistsAtPath:plistPath]) {
				infoPlist = [NSDictionary dictionaryWithContentsOfFile:plistPath];
				
				if ([name isEqualToString:@"GPG Suite"]) {
					NSString *versionPlistPath = [path.stringByDeletingLastPathComponent stringByAppendingPathComponent:@"version.plist"];
					NSDictionary *secondPlist = [NSDictionary dictionaryWithContentsOfFile:versionPlistPath];
					if (secondPlist[@"CFBundleVersion"]) {
						NSMutableDictionary *mutablePlist = [[infoPlist mutableCopy] autorelease];
						mutablePlist[@"CFBundleVersion"] = secondPlist[@"CFBundleVersion"];
						infoPlist = [[mutablePlist copy] autorelease];
					}
				}
				
				break;
			}
		}
		
		
		if (!infoPlist) {
			[versions addObject:@{@"name": name}];
		} else {
			NSArray *parts = [infoPlist[@"CFBundleShortVersionString"] componentsSeparatedByString:@" "];
			
			NSString *commit = @"";
			if (parts.count > 1) {
				commit = parts[1];
			} else {
				commit = [NSString stringWithFormat:@"(%@)", infoPlist[@"CommitHash"]];
			}
			
			NSString *build = infoPlist[@"CFBundleVersion"];
			build = [build stringByReplacingOccurrencesOfString:@"a" withString:@""];
			build = [build stringByReplacingOccurrencesOfString:@"b" withString:@""];

			[versions addObject:@{@"name": name,
								  @"version": parts[0],
								  @"build": build,
								  @"commit": commit
								  }];
			
		}
		
	}
	
	return versions;
}



- (NSString *)versionInfo {
	NSMutableString *infoString = [NSMutableString string];
	NSArray *toolVersions = self.toolVersions;
	
	
	for (NSDictionary *toolVersion in toolVersions) {
		if (toolVersion[@"version"]) {
			NSString *name = toolVersion[@"name"];
			NSString *version = toolVersion[@"version"];
			NSString *build = toolVersion[@"build"];
			NSString *commit = toolVersion[@"commit"];
			
			[infoString appendFormat:@"    %@%@%@",
			 [name stringByPaddingToTab:6],
			 [version stringByPaddingToTab:3],
			 [build stringByPaddingToTab:1]];
			
			if (commit.length > 1) {
				[infoString appendFormat:@"\t%@", commit];
			}
			[infoString appendString:@"\n"];

		} else {
			[infoString appendFormat:@"    %@\t-\n", toolVersion[@"name"]];
		}
	}

	return infoString;
}

- (NSAttributedString *)attributedVersions {
	NSMutableString *infoString = [NSMutableString string];
	NSArray *toolVersions = self.toolVersions;
	
	
	for (NSDictionary *toolVersion in toolVersions) {
		NSString *name = toolVersion[@"name"];
		NSString *version = toolVersion[@"version"];
		if (version) {
			NSString *build = toolVersion[@"build"];
			NSString *commit = toolVersion[@"commit"];
			
			[infoString appendFormat:@"%@\t%@\t%@",
			 name,
			 version,
			 build];
			
			if (commit.length > 1) {
				[infoString appendFormat:@"\t%@", commit];
			}
			[infoString appendString:@"\n"];
		} else {
			[infoString appendFormat:@"%@\t-\n", name];
		}
	}
	
	
	
	NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle new] autorelease];
	paragraphStyle.tabStops = @[[[[NSTextTab alloc] initWithTextAlignment:0 location:155 options:@{}] autorelease],
								[[[NSTextTab alloc] initWithTextAlignment:0 location:235 options:@{}] autorelease],
								[[[NSTextTab alloc] initWithTextAlignment:0 location:310 options:@{}] autorelease]];
	
	paragraphStyle.headIndent = DBL_EPSILON; // Fix for Sierra. tabStops doesn't work if headIndent is 0.
	
	NSAttributedString *attributedVersions = [[[NSAttributedString alloc] initWithString:infoString attributes:@{NSParagraphStyleAttributeName:paragraphStyle}] autorelease];

	
	
	return attributedVersions;
}




#pragma mark TextView styling.

- (NSFont *)textViewFont {
	return [NSFont systemFontOfSize:[NSFont systemFontSize]];
}
- (void)setTextView1:(NSTextView *)value {
	_textView1 = value;
	if (value) {
		[value setTextContainerInset:NSMakeSize(-2, 0)];
	}
}
- (NSTextView *)textView1 {
	return _textView1;
}
- (void)setTextView2:(NSTextView *)value {
	_textView2 = value;
	if (value) {
		[value setTextContainerInset:NSMakeSize(-2, 0)];
	}
}
- (NSTextView *)textView2 {
	return _textView2;
}
- (void)setTextView3:(NSTextView *)value {
	_textView3 = value;
	if (value) {
		[value setTextContainerInset:NSMakeSize(-2, 0)];
	}
}
- (NSTextView *)textView3 {
	return _textView3;
}



@end
