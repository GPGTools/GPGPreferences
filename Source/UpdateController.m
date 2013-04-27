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
@end


@implementation UpdateController
@synthesize updater;
NSDictionary *allOptions;



+ (void)initialize {
	NSDictionary *domains = @{@"macgpg2" : @"org.gpgtools.macgpg2.updater", @"gpgmail" : @"org.gpgtools.gpgmail", @"gpgservices" : @"org.gpgtools.gpgservices", @"gka" : @"org.gpgtools.gpgkeychainaccess", @"gpgprefs" : @"org.gpgtools.gpgpreferences"};
	NSMutableDictionary *tempOptions = [NSMutableDictionary dictionaryWithCapacity:domains.count];

	for (NSString *tool in domains) {
		GPGOptions *options = [GPGOptions new];
		options.standardDomain = domains[tool];
		
		tempOptions[tool] = options;
		[options release];
	}
	
	allOptions = [tempOptions copy];
}

- (id)init {
	if (!(self = [super init])) {
		return nil;
	}
	self.updater = [SUUpdater updaterForBundle:[NSBundle bundleForClass:[self class]]];
	updater.delegate = self;
	
	return self;
}

- (void)dealloc {
	self.updater = nil;
	[super dealloc];
}


- (NSString *)feedURLStringForUpdater:(SUUpdater *)updater {
	NSString *updateSourceKey = @"UpdateSource";
	NSBundle *bundle = [NSBundle bundleForClass:[self class]];
	
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

- (id)valueForKey:(NSString *)key {
	if (allOptions[key]) {
		//Prevent valueForUndefinedKey.
		return nil;
	}
	return [super valueForKey:key];
}


- (GPGOptions *)optionsAndKey:(NSString **)key forKeyPath:(NSString *)keyPath {
	NSRange range = [keyPath rangeOfString:@"."];
	if (range.length == 0) {
		return nil;
	}
	NSString *tool = [keyPath substringToIndex:range.location];
	*key = [keyPath substringFromIndex:range.location + 1];
	
	GPGOptions *options = allOptions[tool];
	if (!options) {
		return nil;
	}
	
	return options;
}


- (id)valueForKeyPath:(NSString *)keyPath {
	NSString *key = nil;
	GPGOptions *options = [self optionsAndKey:&key forKeyPath:keyPath];
	
	if (!options) {
		return [super valueForKeyPath:keyPath];
	}
	
	
	if ([key isEqualToString:@"CheckInterval"]) {
		id value = [options valueInStandardDefaultsForKey:@"SUEnableAutomaticChecks"];
		 
		if ([value respondsToSelector:@selector(boolValue)] && [value boolValue]) {
			return [options valueInStandardDefaultsForKey:@"SUScheduledCheckInterval"];
		}
		
		return @0;
	} else if ([key isEqualToString:@"UpdateType"]) {
		id value = [options valueInStandardDefaultsForKey:@"UpdateSource"];
		
		if ([value isEqualTo:@"stable"]) {
			return @0;
		} else if ([value isEqualTo:@"prerelease"]) {
			return @1;
		} else if ([value isEqualTo:@"nightly"]) {
			return @2;
		}
		
		//TODO: Detect installed version!
		return @0;
	}
	
	return [options valueInStandardDefaultsForKey:key];
}


- (void)setValue:(id)value forKeyPath:(NSString *)keyPath {
	NSString *key = nil;
	GPGOptions *options = [self optionsAndKey:&key forKeyPath:keyPath];
	
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
			[options setValueInStandardDefaults:@YES forKey:@"SUEnableAutomaticChecks"];
		} else {
			[options setValueInStandardDefaults:nil forKey:@"SUScheduledCheckInterval"];
			[options setValueInStandardDefaults:@NO forKey:@"SUEnableAutomaticChecks"];
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






@end
