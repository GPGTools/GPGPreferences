//
//  GPGPVersionInfo.m
//  GPGPreferences
//
//  Created by Mento on 19.06.20.
//  Copyright © 2020 GPGTools. All rights reserved.
//

#import "GPGPVersionInfo.h"
#import "GPGDebugCollector.h"
#import "GMSupportPlanManager.h"


@implementation GPGPVersionInfo

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
	NSString *mailBundleLocation = @"/Library/Application Support/GPGTools/GPGMail/GPGMail_%i.mailbundle";
	if (osVersionParts.count > 1) {
		int osVersion = osVersionParts[1].intValue;
		if (osVersion > 12) {
            if([[GMSupportPlanManager alwaysLoadVersionSharedAccess] isEqualToString:@"3"]) {
                [mailBundleLocations addObject:[NSString stringWithFormat:mailBundleLocation, 3]];
            }
            else {
                [mailBundleLocations addObject:[NSString stringWithFormat:mailBundleLocation, 4]];
            }
		}
		[mailBundleLocations addObject:[NSString stringWithFormat:mailBundleLocation, osVersion]];
	}
	[mailBundleLocations addObjectsFromArray:@[@"/Network/Library/Mail/Bundles/GPGMail.mailbundle", @"~/Library/Mail/Bundles/GPGMail.mailbundle", @"/Library/Mail/Bundles/GPGMail.mailbundle"]];
	
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
		NSString *name = toolVersion[@"name"];
		if (toolVersion[@"version"]) {
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
			
			
			[infoString appendFormat:@"%-22s %-10s %-10s",
			 nameField.UTF8String, version.UTF8String, build.UTF8String];
			
			if (commit.length > 1) {
				[infoString appendFormat:@" %@", commit];
			}

			if([name isEqualToString:@"GPG Mail"]) {
				NSString *supportPlanStatus = [self humanReadableSupportPlanStatus];
				if(supportPlanStatus) {
					[infoString appendFormat:@" %@", supportPlanStatus];
				}
			}

			[infoString appendString:@"\n"];

		} else {
			[infoString appendFormat:@"%-22s -\n", name.UTF8String];
		}
	}

	return infoString;
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
	NSString *bundlesDir = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Containers/com.apple.mail/Data/DataVaults/MailBundles/Library/Mail/Bundles"];
	NSArray *loaderNames = @[@"GPGMailLoader.mailbundle", @"GPGMailLoader_2.mailbundle", @"GPGMailLoader_3.mailbundle"];
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

- (GMSupportPlanManager *)supportPlanManager {
    NSBundle *gpgMailBundle = nil;
    if([[GMSupportPlanManager alwaysLoadVersionSharedAccess] isEqualToString:@"3"]) {
        gpgMailBundle = [self GPGMailBundleForVersion:@"3"];
    }
    else {
        gpgMailBundle = [self GPGMailBundleForVersion:@"4"];
    }

    GMSupportPlanManager *manager = [[GMSupportPlanManager alloc] initWithApplicationID:[gpgMailBundle bundleIdentifier] applicationInfo:[gpgMailBundle infoDictionary] fromSharedAccess:YES];


    return manager;
}

- (NSBundle *)GPGMailBundleForVersion:(NSString *)version {
    NSString *bundlePath = [NSString stringWithFormat:@"/Library/Application Support/GPGTools/GPGMail/GPGMail_%@.mailbundle", version];
    NSBundle *bundle = [NSBundle bundleWithPath:bundlePath];

    return bundle;
}


#pragma mark Singleton: alloc, init etc.
+ (instancetype)sharedInstance {
	static id sharedInstance = nil;
    if (!sharedInstance) {
        sharedInstance = [[super allocWithZone:nil] init];
    }
    return sharedInstance;
}
- (id)init {
	static BOOL initialized = NO;
	if (!initialized) {
		initialized = YES;
		self = [super init];
	}
	return self;
}
+ (id)allocWithZone:(NSZone *)zone {
    return [self sharedInstance];
}
- (id)copyWithZone:(NSZone *)zone {
    return self;
}

@end
