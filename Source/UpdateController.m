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
@property (retain) SUUpdater *updater;
@property (assign) NSBundle *bundle;
@end


@implementation UpdateController
@synthesize updater, bundle;
NSMutableDictionary *tools;
/* tools[tool][key]. key is an of: 
 @"options"			GPGOptions*
 @"path"			NSString*
 @"infoPlist"		NSDictionary*
 @"canSendActions"	NSNumber*
 */



// Init, alloc etc.
+ (void)initialize {
#define DKEY @"domain"
#define PKEY @"path"
#define IKEY @"identifier"
	NSDictionary *toolInfos = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSDictionary dictionaryWithObjectsAndKeys:@"org.gpgtools.macgpg2.updater", DKEY, @"/usr/local/MacGPG2/libexec/MacGPG2_Updater.app", PKEY, nil],
		@"macgpg2",
		
		[NSDictionary dictionaryWithObjectsAndKeys:[NSArray arrayWithObjects:@"../Containers/com.apple.mail/Data/Library/Preferences/org.gpgtools.gpgmail", @"org.gpgtools.gpgmail", nil], DKEY, [NSArray arrayWithObjects:@"/Network/Library/Mail/Bundles/GPGMail.mailbundle", @"~/Library/Mail/Bundles/GPGMail.mailbundle", @"/Library/Mail/Bundles/GPGMail.mailbundle", nil], PKEY, nil],
		@"gpgmail",
		
		[NSDictionary dictionaryWithObjectsAndKeys:@"org.gpgtools.gpgservices", DKEY, [NSArray arrayWithObjects:@"~/Library/Services/GPGServices.service", @"/Library/Services/GPGServices.service", nil], PKEY, nil],
		@"gpgservices",
		
		[NSDictionary dictionaryWithObjectsAndKeys:@"org.gpgtools.gpgkeychainaccess", DKEY, @"org.gpgtools.gpgkeychainaccess", IKEY, nil],
		@"gka",
		
		[NSDictionary dictionaryWithObjectsAndKeys:@"org.gpgtools.gpgpreferences", DKEY, [NSArray arrayWithObjects:@"~/Library/PreferencePanes/GPGPreferences.prefPane", @"/Library/PreferencePanes/GPGPreferences.prefPane", nil], PKEY, nil],
		@"gpgprefs",
		nil];
//  
//  
//  
//  
//  @{
//		@"macgpg2" :		@{DKEY : @"org.gpgtools.macgpg2.updater", PKEY : @"/usr/local/MacGPG2/libexec/MacGPG2_Updater.app"},
//		@"gpgmail" :		@{DKEY : @[@"../Containers/com.apple.mail/Data/Library/Preferences/org.gpgtools.gpgmail", @"org.gpgtools.gpgmail"], PKEY : @[@"/Network/Library/Mail/Bundles/GPGMail.mailbundle", @"~/Library/Mail/Bundles/GPGMail.mailbundle", @"/Library/Mail/Bundles/GPGMail.mailbundle"]},
//		@"gpgservices" :	@{DKEY : @"org.gpgtools.gpgservices", PKEY : @[@"~/Library/Services/GPGServices.service", @"/Library/Services/GPGServices.service"]},
//		@"gka" :			@{DKEY : @"org.gpgtools.gpgkeychainaccess", IKEY : @"org.gpgtools.gpgkeychainaccess"},
//		@"gpgprefs" :		@{DKEY : @"org.gpgtools.gpgpreferences", PKEY : @[@"~/Library/PreferencePanes/GPGPreferences.prefPane", @"/Library/PreferencePanes/GPGPreferences.prefPane"]}
//		};
	
	tools = [[NSMutableDictionary alloc] initWithCapacity:[toolInfos count]];
	
	
	NSString *prefDir = [NSHomeDirectory() stringByAppendingString:@"/Library/Preferences/"];
	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	for (NSString *tool in toolInfos) {
		NSMutableDictionary *toolDict = [NSMutableDictionary dictionary];
		NSDictionary *toolInfo = [toolInfos objectForKey:tool];
		
		
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
			NSString *plistPath = [[path stringByExpandingTildeInPath] stringByAppendingPathComponent:@"Contents/Info.plist"];
			if ([fileManager fileExistsAtPath:plistPath]) {
				[toolDict setObject:path forKey:@"path"];
				[toolDict setObject:[NSDictionary dictionaryWithContentsOfFile:plistPath] forKey:@"infoPlist"];
				break;
			}
		}
		
		
		if ([tool isEqualToString:@"gpgprefs"]) {
			[toolDict setObject:[NSNumber numberWithBool:YES] forKey:@"canSendActions"];
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
	updater.delegate = self;
	
	return self;
}

- (void)dealloc {
	self.updater = nil;
	[super dealloc];
}


- (id)defaultsValueForKey:(NSString *)key forTool:(NSString *)tool {
	NSDictionary *toolDict = [tools objectForKey:tool];
	id value = [[toolDict objectForKey:@"options"] valueInStandardDefaultsForKey:key];

	if (!value) {
		value = [[toolDict objectForKey:@"infoPlist"] objectForKey:key];
	}
	return value;
}


// Getter and setter.
- (id)valueForKeyPath:(NSString *)keyPath {
	NSString *key = nil;
	NSString *tool = [self toolAndKey:&key forKeyPath:keyPath];
	GPGOptions *options = [[tools objectForKey:tool] objectForKey:@"options"];
	
	if (!tool) {
		return [super valueForKeyPath:keyPath];
	}

	
	if ([key isEqualToString:@"CheckInterval"]) {
		id value = [self defaultsValueForKey:@"SUEnableAutomaticChecks" forTool:tool];
		
		if ([value respondsToSelector:@selector(boolValue)] && [value boolValue]) {
			value = [self defaultsValueForKey:@"SUScheduledCheckInterval" forTool:tool];
			return value ? value : [NSNumber numberWithInteger:86400];
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
	} else if ([key isEqualToString:@"CanSendActions"]) {
		return [[tools objectForKey:tool] objectForKey:@"canSendActions"];
	} else if ([key isEqualToString:@"buildNumberDescription"]) {
		NSDictionary *plist = [[tools objectForKey:tool] objectForKey:@"infoPlist"];
		if (!plist) {
			return nil;
		}
		
		return [NSString stringWithFormat:[self.bundle localizedStringForKey:@"BUILD: %@" value:nil table:nil], [plist objectForKey:@"CFBundleVersion"]];
	} else if ([key isEqualToString:@"versionDescription"]) {
		NSDictionary *plist = [[tools objectForKey:tool] objectForKey:@"infoPlist"];
		if (!plist) {
			return nil;
		}

		return [NSString stringWithFormat:[self.bundle localizedStringForKey:@"VERSION: %@" value:nil table:nil], [plist objectForKey:@"CFBundleShortVersionString"]];
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




// Actions
- (void)checkForUpdatesForTool:(NSString *)tool{
	if ([tool isEqualToString:@"gpgprefs"]) {
		[updater checkForUpdates:self];
	}
}



// Helper and other methods.
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



// For own Sparkle.
- (NSString *)feedURLStringForUpdater:(SUUpdater *)updater {
	NSString *updateSourceKey = @"UpdateSource";
	NSBundle *bundle = self.bundle;
	
	NSString *feedURLKey = @"SUFeedURL";
	NSString *appcastSource = [[GPGOptions sharedOptions] stringForKey:updateSourceKey];
	if ([appcastSource isEqualToString:@"nightly"]) {
		feedURLKey = @"SUFeedURL_nightly";
	} else if ([appcastSource isEqualToString:@"prerelease"]) {
		feedURLKey = @"SUFeedURL_prerelease";
	} else if (![appcastSource isEqualToString:@"stable"]) {
		NSString *version = [bundle objectForInfoDictionaryKey:@"CFBundleVersion"];
		if ([version rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"nN"]].length > 0) {
			feedURLKey = @"SUFeedURL_nightly";
		} else if ([version rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"abAB"]].length > 0) {
			feedURLKey = @"SUFeedURL_prerelease";
		}
	}
	
	NSString *appcastURL = [bundle objectForInfoDictionaryKey:feedURLKey];
	if (!appcastURL) {
		appcastURL = [bundle objectForInfoDictionaryKey:@"SUFeedURL"];
	}
	return appcastURL;
}


@end