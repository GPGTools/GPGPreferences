//
//  UpdateController.m
//  GPGPreferences
//
//  Created by Mento on 26.04.2013
//
//

#import <Libmacgpg/Libmacgpg.h>
#import "UpdateController.h"

@interface UpdateController()
@property (strong) SUUpdater *updater;
@property (assign) NSBundle *bundle;
@end

@interface NSString (PadWithTabs)
- (NSString *)stringByPaddingToTab:(NSUInteger)tab;
@end
@implementation NSString (PadWithTabs)
- (NSString *)stringByPaddingToTab:(NSUInteger)tab {
	NSUInteger length = self.length;
	return [self stringByPaddingToLength:length + tab - (length / 4) withString:@"\t" startingAtIndex:0];
}
@end



@implementation UpdateController
@synthesize updater, bundle;
NSMutableDictionary *tools;
/* tools[tool][key]. key is an of: 
 @"options"			GPGOptions*
 @"path"			NSString*
 @"infoPlist"		NSDictionary*
 */



// Init, alloc etc.
+ (void)initialize {
#define DKEY @"domain"
#define PKEY @"path"
#define IKEY @"identifier"
#define NKEY @"toolname"
#define LKEY @"plist"
	
	NSDictionary *toolInfos = @{
		@"macgpg2":		@{NKEY: @"MacGPG2",
						  DKEY: @"org.gpgtools.macgpg2.updater",
						  PKEY: @"/usr/local/MacGPG2/libexec/MacGPG2_Updater.app"},
		
		@"gpgservices":	@{NKEY: @"GPGServices",
						  DKEY: @"org.gpgtools.gpgservices",
						  PKEY: @[@"~/Library/Services/GPGServices.service", @"/Library/Services/GPGServices.service"]},
		
		@"gka":			@{NKEY: @"GPG Keychain",
						  DKEY: @"org.gpgtools.gpgkeychain",
						  IKEY: @"org.gpgtools.gpgkeychain"},
		
		@"gpgprefs":	@{NKEY: @"GPGPreferences",
						  DKEY: @"org.gpgtools.gpgpreferences",
						  PKEY: @[@"~/Library/PreferencePanes/GPGPreferences.prefPane", @"/Library/PreferencePanes/GPGPreferences.prefPane"]},
		
		@"gpgmail":		@{NKEY: @"GPGMail",
						  DKEY: @[@"../Containers/com.apple.mail/Data/Library/Preferences/org.gpgtools.gpgmail", @"org.gpgtools.gpgmail"],
						  PKEY: @[@"/Network/Library/Mail/Bundles/GPGMail.mailbundle", @"~/Library/Mail/Bundles/GPGMail.mailbundle", @"/Library/Mail/Bundles/GPGMail.mailbundle"]},
		
		@"libmacgpg":	@{NKEY: @"Libmacgpg",
						  DKEY: @"org.gpgtools.libmacgpg",
						  PKEY: @[@"~/Library/Frameworks/Libmacgpg.framework", @"/Library/Frameworks/Libmacgpg.framework"],
						  LKEY: @"Resources/Info.plist"},
		
		@"pinentry":	@{NKEY: @"Pinentry",
						  DKEY: @"org.gpgtools.pinentry-mac",
						  PKEY: @[@"/usr/local/MacGPG2/libexec/pinentry-mac.app"]}
	};
	
	tools = [[NSMutableDictionary alloc] initWithCapacity:[toolInfos count]];
	
	
	NSString *prefDir = [NSHomeDirectory() stringByAppendingString:@"/Library/Preferences/"];
	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	for (NSString *tool in toolInfos) {
		NSMutableDictionary *toolDict = [NSMutableDictionary dictionary];
		NSDictionary *toolInfo = [toolInfos objectForKey:tool];
		
		// Readable name of the tool.
        [toolDict setValue:[toolInfo objectForKey:NKEY] forKey:NKEY];
        
		// GPGOptions for every tool.
		id domains = [toolInfo objectForKey:DKEY]; //NSString or NSArray of NSStrings.
		NSString *domain = nil;
		
		if ([domains isKindOfClass:[NSArray class]]) {
			// Use the first plist, which exists.
			for (NSString *aDomain in domains) {
				NSString *path = [prefDir stringByAppendingFormat:@"%@.plist", aDomain];
				if ([fileManager fileExistsAtPath:path]) {
					domain = aDomain;
					break;
				}
			}
			if (!domain) {
				domain = [domains objectAtIndex:0];
			}
		} else {
			domain = domains;
		}
		
		GPGOptions *options = [GPGOptions new];
		options.standardDomain = domain;
		
		[toolDict setObject:options forKey:@"options"];
		[options release];
		
		
		// Paths to the tools.
		id paths = [toolInfo objectForKey:PKEY];
		if (!paths) {
			NSString *path = [[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier:[toolInfo objectForKey:IKEY]];
			paths = path ? [NSArray arrayWithObject:path] : [NSArray array];
		} else if (![paths isKindOfClass:[NSArray class]]) {
			paths = [NSArray arrayWithObject:paths];
		}
		
		for (NSString *path in paths) {
			path = [path stringByExpandingTildeInPath];
			NSString *plistPath = [toolInfo objectForKey:LKEY];
			if (!plistPath) {
				plistPath = @"Contents/Info.plist";
			}
			plistPath = [path stringByAppendingPathComponent:plistPath];
			if ([fileManager fileExistsAtPath:plistPath]) {
				[toolDict setObject:path forKey:@"path"];
				[toolDict setObject:[NSDictionary dictionaryWithContentsOfFile:plistPath] forKey:@"infoPlist"];
				break;
			}
		}
		
		
		// Set the dict for the tool.
		[tools setObject:toolDict forKey:tool];
	}
}

- (id)init {
	if (!(self = [super init])) {
		return nil;
	}
	self.bundle = [NSBundle bundleForClass:[self class]];
		
	self.updater = [SUUpdater updaterForBundle:self.bundle];
	[updater setDelegate:self];

	
	return self;
}
	 
	 

- (void)dealloc {
	self.updater = nil;
	[super dealloc];
}

// Getter and setter.
- (id)defaultsValueForKey:(NSString *)key forTool:(NSString *)tool {
	NSDictionary *toolDict = [tools objectForKey:tool];
	id value = [[toolDict objectForKey:@"options"] valueInStandardDefaultsForKey:key];

	if (!value) {
		value = [[toolDict objectForKey:@"infoPlist"] objectForKey:key];
	}
	return value;
}

- (id)valueForKeyPath:(NSString *)keyPath {
	NSString *key = nil;
	NSString *tool = [self toolAndKey:&key forKeyPath:keyPath];
	GPGOptions *options = [[tools objectForKey:tool] objectForKey:@"options"];
	
	if (!tool) {
		return [super valueForKeyPath:keyPath];
	}

	
	if ([key isEqualToString:@"CheckInterval"]) {
		id value = [self defaultsValueForKey:@"SUEnableAutomaticChecks" forTool:tool];
		
		if (value == nil || ([value respondsToSelector:@selector(boolValue)] && [value boolValue])) {
			value = [self defaultsValueForKey:@"SUScheduledCheckInterval" forTool:tool];
			NSInteger number = value ? [value integerValue] : 86400;
			if (number != 0 && number != 86400 && number != 604800) {
				// Only allow Never, Daily and Weekly.
				value = [NSNumber numberWithInteger:86400];
				[options setValueInStandardDefaults:value forKey:@"SUScheduledCheckInterval"];
			}
			return value;
		}
		
		return [NSNumber numberWithInteger:0];
	} else if ([key isEqualToString:@"UpdateType"]) {
		id value = [options valueInStandardDefaultsForKey:@"UpdateSource"];
		
		if ([value isEqualTo:@"stable"]) {
			return [NSNumber numberWithInteger:0];
		} else if ([value isEqualTo:@"prerelease"]) {
			return [NSNumber numberWithInteger:1];
		} else if ([value isEqualTo:@"nightly"]) {
			return [NSNumber numberWithInteger:2];
		}
		
		NSDictionary *plist = [[tools objectForKey:tool] objectForKey:@"infoPlist"];
		if (plist) {
			NSString *version = [plist objectForKey:@"CFBundleVersion"];
			if ([version rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"nN"]].length > 0) {
				return [NSNumber numberWithInteger:2];
			} else if ([version rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"abAB"]].length > 0) {
				return [NSNumber numberWithInteger:1];
			}
		}
		
		return [NSNumber numberWithInteger:0];
	} else if ([key isEqualToString:@"Installed"]) {
		return [NSNumber numberWithBool:!![[tools objectForKey:tool] objectForKey:@"path"]];
	} else if ([key isEqualToString:@"Path"]) {
		return [[tools objectForKey:tool] objectForKey:@"path"];
	} else if ([key isEqualToString:@"versionDescription"]) {
		NSString *name = [[tools objectForKey:tool] objectForKey:NKEY];

		NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:name attributes:@{NSFontAttributeName: [NSFont systemFontOfSize:[NSFont systemFontSize]]}];
		
		NSDictionary *plist = [[tools objectForKey:tool] objectForKey:@"infoPlist"];
		if (!plist) {
			return attributedString;
		}
		
		NSString *version = plist[@"CFBundleShortVersionString"];
		NSString *build = plist[@"CFBundleVersion"];
		
		NSString *string = [NSString stringWithFormat:@"   %@ %@", version, build];
		
		
		NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
		//[paragraphStyle setTabStops:@[[[NSTextTab alloc] initWithType:NSLeftTabStopType location:150]]];
		
		NSDictionary *attributes = @{NSFontAttributeName: [NSFont systemFontOfSize:[NSFont smallSystemFontSize]], NSParagraphStyleAttributeName: paragraphStyle};
		
		
		NSAttributedString *versionString =[[[NSAttributedString alloc] initWithString:string attributes:attributes] autorelease];
		
		[attributedString appendAttributedString:versionString];
		
		
		NSUInteger stringLength = attributedString.length;
		NSUInteger buildLength = build.length;
		
		[attributedString addAttribute:NSForegroundColorAttributeName value:[NSColor grayColor] range:NSMakeRange(stringLength - buildLength, buildLength)];
		
		

		return attributedString;
	} else if ([key isEqualToString:@"image"]) {
		NSImage *image = nil;
		if ([[tools objectForKey:tool] objectForKey:@"path"]) {
			image = [[tools objectForKey:tool] objectForKey:@"image"];
			if (!image) {
				image = [[NSImage alloc] initByReferencingFile:[self.bundle pathForImageResource:tool]];
				//image = [self.bundle imageForResource:tool]; /* DO NOT USE imageForResource: on 10.6 */
				[[tools objectForKey:tool] setObject:image forKey:@"image"];
			}
		} else {
			image = [[tools objectForKey:tool] objectForKey:@"image-gray"];
			if (!image) {
				image = [[NSImage alloc] initByReferencingFile:[self.bundle pathForImageResource:[tool stringByAppendingString:@"-gray"]]];
				//image = [self.bundle imageForResource:[tool stringByAppendingString:@"-gray"]]; /* DO NOT USE imageForResource: on 10.6 */
				[[tools objectForKey:tool] objectForKey:@"image-gray"];
			}
		}
		return image;
	} else if ([key isEqualToString:@"text-color"]) {
		return [[tools objectForKey:tool] objectForKey:@"path"] ? [NSColor blackColor] : [NSColor grayColor];
	}
	
	
	
	return [options valueInStandardDefaultsForKey:key];
}

- (void)setValue:(id)value forKeyPath:(NSString *)keyPath {
	NSString *key = nil;
	NSString *tool = [self toolAndKey:&key forKeyPath:keyPath];
	GPGOptions *options = [[tools objectForKey:tool] objectForKey:@"options"];
	
	if (!options) {
		[super setValue:value forKeyPath:keyPath];
		return;
	}

	int intValue = 0;
	if ([value respondsToSelector:@selector(intValue)]) {
		intValue = [value intValue];
	}
	
	if ([key isEqualToString:@"CheckInterval"]) {
		if (intValue > 0) {
			[options setValueInStandardDefaults:value forKey:@"SUScheduledCheckInterval"];
			[options setValueInStandardDefaults:[NSNumber numberWithBool:YES] forKey:@"SUEnableAutomaticChecks"];
		} else {
			[options setValueInStandardDefaults:nil forKey:@"SUScheduledCheckInterval"];
			[options setValueInStandardDefaults:[NSNumber numberWithBool:NO] forKey:@"SUEnableAutomaticChecks"];
		}
	} else if ([key isEqualToString:@"UpdateType"]) {
		NSString *type;
		switch (intValue) {
			case 1:
				type = @"prerelease";
				break;
			case 2:
				type = @"nightly";
				break;
			default:
				type = @"stable";
				break;
		}
		[options setValueInStandardDefaults:type forKey:@"UpdateSource"];
	} else {
		[options setValueInStandardDefaults:value forKey:key];
	}
}

- (NSString *)toolAndKey:(NSString **)key forKeyPath:(NSString *)keyPath {
	NSRange range = [keyPath rangeOfString:@"."];
	if (range.length == 0) {
		return nil;
	}
	*key = [keyPath substringFromIndex:range.location + 1];
	
	return [keyPath substringToIndex:range.location];
}

- (id)valueForKey:(NSString *)key {
	if ([tools objectForKey:key]) {
		//Prevent valueForUndefinedKey.
		return key;
	}
	return [super valueForKey:key];
}




// Actions
- (void)checkForUpdatesForTool:(NSString *)tool{
	if ([tool isEqualToString:@"gpgprefs"]) {
		[updater checkForUpdates:self];
	} else if ([tool isEqualToString:@"macgpg2"]) {
		[NSTask launchedTaskWithLaunchPath:@"/usr/local/MacGPG2/libexec/MacGPG2_Updater.app/Contents/MacOS/MacGPG2_Updater" arguments:@[@"checkNow"]];
	} else if ([tool isEqualToString:@"gpgmail"]) {
		if (NSAppKitVersionNumber >= NSAppKitVersionNumber10_7) {
			@try {
				[NSTask launchedTaskWithLaunchPath:@"/Library/Application Support/GPGTools/GPGMail_Updater.app/Contents/MacOS/GPGMail_Updater" arguments:@[@"checkNow"]];
			}
			@catch (NSException *exception) {
				localizedAlert(@"UpdateCheckFailed");
			}
		} else {
			/* Mac OS X 10.6 */
			localizedAlert(@"NoUpdatesGM106");
		}
	} else if ([tool isEqualToString:@"gka"]) {
		NSAppleScript *script = [[NSAppleScript alloc] initWithSource:@"tell application \"GPG Keychain\"\ncheck for updates\nactivate\nend tell"];
		[script executeAndReturnError:nil];
	} else if ([tool isEqualToString:@"gpgservices"]) {
		NSString *path = [[tools objectForKey:tool] objectForKey:PKEY];
		NSString *scriptText = [NSString stringWithFormat:@"tell application \"%@\"\ncheck for updates\nactivate\nend tell", path];
		NSAppleScript *script = [[NSAppleScript alloc] initWithSource:scriptText];
		[script executeAndReturnError:nil];
	}
}

- (IBAction)openDownloadSite:(id)sender {
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://gpgtools.org/#gpgsuite"]];
}

- (IBAction)copyVersionInfo:(NSButton *)sender {
	NSMutableString *infoString = [NSMutableString string];
	NSDictionary *systemPlist = [NSDictionary dictionaryWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"];
	
	
	[infoString appendFormat:@"Mac OS X\t\t%@\t\t\t\t(%@)\n", [systemPlist objectForKey:@"ProductVersion"] , [systemPlist objectForKey:@"ProductBuildVersion"]];
	
	
	NSArray *toolKeys = @[@"libmacgpg", @"gpgmail", @"gka", @"gpgservices", @"macgpg2", @"gpgprefs", @"pinentry"];
	
	for (NSString *tool in toolKeys) {
		NSDictionary *toolInfo = [tools objectForKey:tool];
		NSDictionary *plist = [toolInfo objectForKey:@"infoPlist"];
		NSString *name = [toolInfo objectForKey:NKEY];

		if (!plist) {
			[infoString appendFormat:@"%@\t-\n", name];
		} else {
			NSArray *parts = [[plist objectForKey:@"CFBundleShortVersionString"] componentsSeparatedByString:@" "];
			[infoString appendFormat:@"%@%@%@",
			 [name stringByPaddingToTab:4],
			 [[parts objectAtIndex:0] stringByPaddingToTab:3],
			 [[plist objectForKey:@"CFBundleVersion"] stringByPaddingToTab:1]];

			if (parts.count > 1) {
				[infoString appendFormat:@"\t%@", [parts objectAtIndex:1]];
			}
			[infoString appendString:@"\n"];
		}
	}
	
	
	NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
	[pasteboard clearContents];
	[pasteboard writeObjects:@[infoString]];
}

- (NSString *)versionInfo {
	NSMutableString *infoString = [NSMutableString string];
	NSDictionary *systemPlist = [NSDictionary dictionaryWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"];
	
	
	[infoString appendFormat:@"    Mac OS X\t\t%@\t\t\t\t(%@)\n", [systemPlist objectForKey:@"ProductVersion"] , [systemPlist objectForKey:@"ProductBuildVersion"]];
	
	
	NSArray *toolKeys = @[@"libmacgpg", @"gpgmail", @"gka", @"gpgservices", @"macgpg2", @"gpgprefs", @"pinentry"];
	
	for (NSString *tool in toolKeys) {
		NSDictionary *toolInfo = [tools objectForKey:tool];
		NSDictionary *plist = [toolInfo objectForKey:@"infoPlist"];
		NSString *name = [toolInfo objectForKey:NKEY];
		
		if (!plist) {
			[infoString appendFormat:@"    %@\t-\n", name];
		} else {
			NSArray *parts = [[plist objectForKey:@"CFBundleShortVersionString"] componentsSeparatedByString:@" "];
			[infoString appendFormat:@"    %@%@%@",
			 [name stringByPaddingToTab:4],
			 [[parts objectAtIndex:0] stringByPaddingToTab:3],
			 [[plist objectForKey:@"CFBundleVersion"] stringByPaddingToTab:1]];
			
			if (parts.count > 1) {
				[infoString appendFormat:@"\t%@", [parts objectAtIndex:1]];
			}
			[infoString appendString:@"\n"];
		}
	}
	
	return infoString;
}



@end







