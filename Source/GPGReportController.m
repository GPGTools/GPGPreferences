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
	[fieldsString appendFormat:@"%@private%@1\r\n--%@", dispo1, dispo2, boundry]; // Make private.
	
    // Fetch support plan information if available.
	GMSupportPlanManager *manager = [self supportPlanManager];
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
					NSString *anon_token = result[@"anon_user_token"];
					if ([anon_token isKindOfClass:[NSString class]]) {
						href = [href stringByAppendingFormat:@"?anon_token=%@", anon_token];
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
			
			self.subject = @"";
			self.affectedComponent = 0;
			self.bugDescription = @"";
			self.expectedBahavior = @"";
			self.additionalInfo = @"";
			self.attachDebugLog = NO;
			
			[gpgPrefPane showAlert:@"Support_PrivateReportSucceeded"
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
	NSLog(@"%@", self.versionInfo);
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
	if (self.attachDebugLog) {
		alert.showsSuppressionButton = NO;
	}
	alert.accessoryView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 380, 0)];

	[gpgPrefPane displayAlert:alert completionHandler:^(NSModalResponse returnCode) {
		BOOL sendLog = NO;
		if (returnCode & 0x800) {
			sendLog = YES;
			returnCode -= 0x800;
		}
		
		if (returnCode == NSAlertFirstButtonReturn || returnCode == NSAlertDefaultReturn) {
			self.uiEnabled = NO;
			if (alert.showsSuppressionButton) {
				self.attachDebugLog = sendLog;
			}
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
	
	_uiEnabled = YES;
	
	return self;
}
- (void)awakeFromNib {
	_options = self.prefController.options;

	[self loadSavedValues];
	
	GMSupportPlanState state = self.supportPlanManager.supportPlanState;
	
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
	NSArray<NSString *> *osVersionParts = [[systemPlist objectForKey:@"ProductVersion"] componentsSeparatedByString:@"."];
	
	// Add locations for GPGMail_12–GPGMail_14 and GPGMail_3–GPGMail_4.
	NSMutableArray *mailBundleLocations = [NSMutableArray array];
    NSString *currentGPGMailPath = [self currentGPGMailPath];
    if(currentGPGMailPath) {
        [mailBundleLocations addObject:currentGPGMailPath];
    }

	NSArray *tools = @[
					   @{NKEY: @"GPG Suite",
						 PKEY: @[@"/Library/Application Support/GPGTools/GPGSuite_Updater.app"]},

					   @{NKEY: @"GPG Mail",
						 PKEY: mailBundleLocations},
					   
					   @{NKEY: @"GPG Keychain",
						 IKEY: @"org.gpgtools.gpgkeychain"},
					   
					   @{NKEY: @"GPG Services",
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

		
	[versions addObject:@{@"name": @"macOS",
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
			NSString *expandedPath = [path stringByExpandingTildeInPath];
			NSString *plistPath = toolInfo[LKEY];
			if (!plistPath) {
				plistPath = @"Contents/Info.plist";
			}
			plistPath = [expandedPath stringByAppendingPathComponent:plistPath];
			if ([fileManager fileExistsAtPath:plistPath]) {
				infoPlist = [NSDictionary dictionaryWithContentsOfFile:plistPath];
				
				if ([name isEqualToString:@"GPG Suite"]) {
					NSString *versionPlistPath = [expandedPath.stringByDeletingLastPathComponent stringByAppendingPathComponent:@"version.plist"];
					NSDictionary *secondPlist = [NSDictionary dictionaryWithContentsOfFile:versionPlistPath];
					if (secondPlist[@"CFBundleVersion"]) {
						NSMutableDictionary *mutablePlist = [infoPlist mutableCopy];
						mutablePlist[@"CFBundleVersion"] = secondPlist[@"CFBundleVersion"];
						infoPlist = [mutablePlist copy];
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
			NSString *nameField = name;
			NSString *version = toolVersion[@"version"];
			NSString *build = toolVersion[@"build"];
			NSString *commit = toolVersion[@"commit"];
			
			
			if ([name isEqualToString:@"GPG Mail"]) {
				NSString *status = [self gpgMailLoadingStateWithToolVersion:toolVersion];
				if (status.length > 0) {
					nameField = [NSString stringWithFormat:@"%@ (%@)", name, status];
				}
			}
			
			
			[infoString appendFormat:@"    %@%@%@",
			 [nameField stringByPaddingToTab:6],
			 [version stringByPaddingToTab:3],
			 [build stringByPaddingToTab:1]];
			
			if (commit.length > 1) {
				[infoString appendFormat:@"\t%@", commit];
			}

			if([name isEqualToString:@"GPG Mail"]) {
				NSString *supportPlanStatus = [self humanReadableSupportPlanStatus];
				if(supportPlanStatus) {
					[infoString appendFormat:@"\t%@", supportPlanStatus];
				}
			}

			[infoString appendString:@"\n"];

		} else {
			[infoString appendFormat:@"    %@\t-\n", toolVersion[@"name"]];
		}
	}

	return infoString;
}

- (NSString *)gpgMailLoadingStateWithToolVersion:(NSDictionary *)toolVersion {
	// First check if GPGMail is installed.
	BOOL gpgMailInstalled = NO;
	if (toolVersion[@"version"]) {
		gpgMailInstalled = YES;
	}
	if (!gpgMailInstalled) {
		return @"";
	}

    // Check if the GPGMailLoader is enabled.
	BOOL loaderEnabled = NO;
    NSString *bundlesDir = [GMSupportPlanManager bundlesContainerPath];
    NSArray *loaderNames = @[@"GPGMailLoader.mailbundle", @"GPGMailLoader_2.mailbundle", @"GPGMailLoader_5.mailbundle", @"GPGMailLoader_6.mailbundle", @"GPGMailLoader_7.mailbundle"];
	NSFileManager *fileManager = [NSFileManager defaultManager];

	for (NSString *loaderName in loaderNames) {
		NSString *path = [bundlesDir stringByAppendingPathComponent:loaderName];
		NSError *error = nil;
		[fileManager attributesOfItemAtPath:path error:&error];
		
		NSError *posixError = error.userInfo[NSUnderlyingErrorKey];
				
		if (!error || (posixError.code == EPERM && [posixError.domain isEqualToString:NSPOSIXErrorDomain])) {
			// No error or "Operation not permitted", this means the files exists.
			loaderEnabled = YES;
			break;
		}
	}

	
	// Check if GPGMail is laoded.
	BOOL gpgMailLoaded = NO;
	NSString *result = [GPGDebugCollector runCommand:@[@"/usr/sbin/lsof", @"-F", @"-c", @"Mail"]];
	if (result && [result rangeOfString:@".mailbundle/Contents/MacOS/GPGMail\n"].length > 0) {
		gpgMailLoaded = YES;
	}
	
	if (loaderEnabled && gpgMailLoaded) {
		return @"loaded";
	} else if (loaderEnabled) {
		return @"enabled";
	} else if (gpgMailLoaded) {
		return @"disabled";
	}
	
	return @"not loaded";
}

- (NSString *)currentGPGMailVersion {
    NSString *forcedVersion = [GMSupportPlanManager alwaysLoadVersionSharedAccess];
    if([forcedVersion length]) {
        return forcedVersion;
    }

    return [self newestGPGMailVersion];
}

- (NSString *)currentGPGMailPath {
    NSString *version = [self currentGPGMailVersion];
    return [self GPGMailPathForVersion:version];
}

- (NSBundle *)currentGPGMailBundle {
    NSString *path = [self currentGPGMailPath];
    NSBundle *bundle = [NSBundle bundleWithPath:path];

    return bundle;
}

- (NSString *)GPGMailPathForVersion:(NSString *)version {
    NSString *realPath = [[GMSupportPlanManager bundlesInstallationPath] stringByAppendingPathComponent:[NSString stringWithFormat:@"GPGMail_%@.real.mailbundle", version]];
    NSString *path = [[GMSupportPlanManager bundlesInstallationPath] stringByAppendingPathComponent:[NSString stringWithFormat:@"GPGMail_%@.mailbundle", version]];

    if([[NSFileManager defaultManager] fileExistsAtPath:realPath]) {
        return realPath;
    }

    return path;
}

- (NSBundle *)GPGMailBundleForVersion:(NSString *)version {
    NSString *bundlePath = [self GPGMailPathForVersion:version];
    NSBundle *bundle = [NSBundle bundleWithPath:bundlePath];

    return bundle;
}

- (NSString *)newestGPGMailVersion {
    NSString *bundlePath = [GMSupportPlanManager bundlesInstallationPath];
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:bundlePath error:nil];
    NSString *prefix = @"GPGMail_";
    NSString *identifierPrefix = @"org.gpgtools.gpgmail";
    NSMutableSet *versions = [NSMutableSet new];
    for(NSString *file in files) {
        if(![[file substringToIndex:[prefix length]] isEqualToString:prefix]) {
            continue;
        }
        // Read bundle identifier from mailbundle.
        NSString *version = [file stringByReplacingOccurrencesOfString:prefix withString:@""];
        version = [version stringByReplacingOccurrencesOfString:@".mailbundle" withString:@""];
        NSBundle *bundle = [self GPGMailBundleForVersion:version];
        NSString *actualVersion = [[bundle bundleIdentifier] stringByReplacingOccurrencesOfString:identifierPrefix withString:@""];
        // Check if the version is really supported, depending on LoaderMinOSVersion if set.
        if(![self bundleSupportsCurrentOS:bundle]) {
            continue;
        }
        if([actualVersion length] <= 0) {
            actualVersion = @"3";
        }
        [versions addObject:actualVersion];
    }

    // Sort the version by newest.
    NSArray *versionsArray = [[versions allObjects] sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        if([obj1 integerValue] < [obj2 integerValue]) {
            return NSOrderedDescending;
        }
        if([obj1 integerValue] > [obj2 integerValue]) {
            return NSOrderedAscending;
        }
        return NSOrderedSame;
    }];

    if([versionsArray count] <= 0) {
        return nil;
    }

    return versionsArray[0];
}

- (NSOperatingSystemVersion)osVersionFromString:(NSString *)osVersion {
    NSArray *versionParts = [osVersion componentsSeparatedByString:@"."];
    NSUInteger majorVersion = [versionParts[0] integerValue];
    NSUInteger minorVersion = [versionParts count] > 1 ? [versionParts[1] integerValue] : 0;
    NSUInteger patchVersion = [versionParts count] > 2 ? [versionParts[2] integerValue] : 0;

    return (NSOperatingSystemVersion){majorVersion, minorVersion, patchVersion};
}

- (BOOL)bundleSupportsCurrentOS:(NSBundle *)bundle {
    NSString *minOSVersionString = [[bundle infoDictionary] objectForKey:@"LoaderMinOSVersion"];
    if([minOSVersionString length] <= 0) {
        return YES;
    }

    NSOperatingSystemVersion minOSVersion = [self osVersionFromString:minOSVersionString];

    BOOL isSupported = [[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:minOSVersion];

    return isSupported;
}

- (NSString *)newestGPGMailPath {
    NSString *version = [self newestGPGMailVersion];
    return [self GPGMailPathForVersion:version];
}

- (NSBundle *)newestGPGMailBundle {
    NSBundle *newestBundle = [self GPGMailBundleForVersion:[self newestGPGMailVersion]];

    return newestBundle;
}

- (GMSupportPlanManager *)supportPlanManager {
    NSBundle *GPGMailBundle = [self currentGPGMailBundle];

    if(!GPGMailBundle) {
        return nil;
    }
    GMSupportPlanManager *manager = [[GMSupportPlanManager alloc] initWithApplicationID:[GPGMailBundle bundleIdentifier] applicationInfo:[GPGMailBundle infoDictionary] fromSharedAccess:YES];

    return manager;
}

- (NSString *)humanReadableSupportPlanStatus {
	// Fetch trial or activated status for GPG Mail.
	if(![[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){10,13,0}]) {
		return nil;
	}
	GMSupportPlanManager *manager = [self supportPlanManager];

    GMSupportPlanState state = [manager supportPlanState];
    if(state == GMSupportPlanStateInactive) {
        return @"Decrypt Only Mode";
    }
    if(state == GMSupportPlanStateTrial) {
        return [NSString stringWithFormat:@"%@ trial days remaining", [manager remainingTrialDays]];
    }
    if(state == GMSupportPlanStateTrialExpired) {
        return @"Trial Expired";
    }
    if(state == GMSupportPlanStateActive) {
        return @"Active Support Plan";
    }

    return @"Decrypt Only Mode";
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
			if([name isEqualToString:@"GPG Mail"]) {
				NSString *supportPlanStatus = [self humanReadableSupportPlanStatus];
				if(supportPlanStatus) {
					[infoString appendFormat:@"\t%@", supportPlanStatus];
				}
			}
			[infoString appendString:@"\n"];
		} else {
			[infoString appendFormat:@"%@\t-\n", name];
		}
	}
	
	
	
	NSMutableParagraphStyle *paragraphStyle = [NSMutableParagraphStyle new];
	paragraphStyle.tabStops = @[[[NSTextTab alloc] initWithTextAlignment:0 location:155 options:@{}],
								[[NSTextTab alloc] initWithTextAlignment:0 location:235 options:@{}],
								[[NSTextTab alloc] initWithTextAlignment:0 location:310 options:@{}],
								[[NSTextTab alloc] initWithTextAlignment:0 location:400 options:@{}]];
	
	paragraphStyle.headIndent = DBL_EPSILON; // Fix for Sierra. tabStops doesn't work if headIndent is 0.
	
	NSAttributedString *attributedVersions = [[NSAttributedString alloc] initWithString:infoString attributes:@{NSParagraphStyleAttributeName:paragraphStyle}];

	
	
	return attributedVersions;
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
