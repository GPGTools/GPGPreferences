//
//  GPGToolsPrefController.m
//  GPGTools
//
//  Created by Alexander Willner on 04.08.10.
//  Edited by Roman Zechmeister 11.07.2011
//  Copyright 2016 GPGTools Project Team. All rights reserved.
//

#import "GPGToolsPrefController.h"
#import <Security/Security.h>
#import <Security/SecItem.h>

#define GPG_SERVICE_NAME "GnuPG"

static NSUInteger const kDefaultPassphraseCacheTime = 600;
static NSString * const AutomaticallySendCrashReportsKey = @"AutomaticallySendCrashReports";
static NSString * const CrashReportsUserEmailKey = @"CrashReportsUserEmail";



@interface GPGToolsPrefController ()
@property (nonatomic) BOOL testingServer;
@property (nonatomic, strong) NSString *keyserverToCheck;
@property (nonatomic, strong) GPGController *gpgc;
@end


@implementation NSArray (For106)
- (id)objectAtIndexedSubscript:(NSUInteger)idx {
	return [self objectAtIndex:idx];
}
@end
@implementation NSDictionary (For106)
- (id)objectForKeyedSubscript:(id)key {
	return [self objectForKey:key];
}
@end




@implementation GPGToolsPrefController
@synthesize options, testingServer, updaterOptions, keyserverToCheck;

- (id)init {
	if (!(self = [super init])) {
		return nil;
	}
	secretKeysLock = [[NSLock alloc] init];
	
	options = [GPGOptions sharedOptions];
	options.standardDomain = @"org.gpgtools.gpgpreferences";
	updaterOptions = [[GPGOptions alloc] init];
	updaterOptions.standardDomain = @"org.gpgtools.updater";
	[[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(keysDidChange:) name:GPGKeyManagerKeysDidChangeNotification object:nil];
	[[GPGKeyManager sharedInstance] loadAllKeys];

	return self;
}
- (void)dealloc {
	[secretKeysLock release];
	[options release];
	[super dealloc];
}


- (void)mainViewDidLoad {
	//[self performSelector:@selector(removeCommentIfWanted) withObject:nil afterDelay:0];
	[self performSelectorOnMainThread:@selector(removeCommentIfWanted) withObject:nil waitUntilDone:NO];
}

- (void)removeCommentIfWanted {
	if (![options boolForKey:@"RemoveCommentCheckRan"]) {
		NSString *comment = [[options valueInGPGConfForKey:@"comment"] componentsJoinedByString:@"\n"];
		NSLog(@"[gpgpreferences] Check if comment is available and warn user.");
		if (comment.length > 0) {
			// Add http option as well, since that was used in the past.
			if ([comment isEqualToString:@"GPGTools - https://gpgtools.org"] || [comment isEqualToString:@"GPGTools - http://gpgtools.org"]) {
				[options setValueInGPGConf:nil forKey:@"comment"];
			} else {
				[gpgPrefPane showAlert:@"ShouldRemoveComment" parameters:@[comment] completionHandler:^(NSModalResponse returnCode) {
					if (returnCode == NSAlertFirstButtonReturn) {
						[options setValueInGPGConf:nil forKey:@"comment"];
					}
				}];
			}
		}
		
		[options setBool:YES forKey:@"RemoveCommentCheckRan"];
	}
}




- (void)setNilValueForKey:(NSString *)key {
    if([key isEqualToString:@"passphraseCacheTime"]) {
        [self setPassphraseCacheTime:kDefaultPassphraseCacheTime];
        return;
    }
}


/*
 * Key-Value Observing
 */
+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key {
	NSSet *affectingKeys = [super keyPathsForValuesAffectingValueForKey:key];
	
	NSSet *keysAffectedBySecretKeys = [NSSet setWithObjects:@"secretKeyDescriptions", @"indexOfSelectedSecretKey", nil];
	if ([keysAffectedBySecretKeys containsObject:key]) {
		affectingKeys = [affectingKeys setByAddingObject:@"secretKeys"];
	}
	
	NSSet *keysAffectedByConf = [NSSet setWithObjects:
								 @"keyserver",
								 @"passphraseCacheTime",
								 @"rememberPassword",
								 @"indexOfSelectedSecretKey",
								 nil];
	if ([keysAffectedByConf containsObject:key]) {
		affectingKeys = [affectingKeys setByAddingObject:@"options.gpgConf"];
	}

	return affectingKeys;
}
+ (NSSet *)keyPathsForValuesAffectingKeyservers {
	return [NSSet setWithObject:@"options.keyservers"];
}
+ (NSSet *)keyPathsForValuesAffectingKeyserver {
	return [NSSet setWithObjects:@"options.keyserver", @"keyserverToCheck", nil];
}



/*
 * Delete stored passphrases from the Mac OS X keychain.
 */
- (IBAction)deletePassphrases:(id)sender {
	[gpgPrefPane showAlert:@"WarningDeletePasswords" parameters:nil completionHandler:^(NSModalResponse returnCode) {
		if (returnCode != NSAlertFirstButtonReturn) {
			return;
		}
		
		BOOL success = YES;
		@try {
			[options gpgAgentFlush];
			
			// On 10.6 and lower the newer SecItemCopyMatching API is available, but generic passwords
			// can't be searched. So on 10.7+ we'll use the newer API, while on 10.6 we fallback to the
			// SecKeychainFindGenericPassword method, which is not quite as handy, since it requires us to know
			// the accountName (which is the fingerprint of the key in our case).
			NSString *serviceName = @"GnuPG";
			OSStatus status;
			
			if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_6) {
				NSDictionary *query = [NSDictionary dictionaryWithObjectsAndKeys:kSecClassGenericPassword, kSecClass, kSecMatchLimitAll, kSecMatchLimit, kCFBooleanTrue, kSecReturnRef, kCFBooleanTrue, kSecReturnAttributes, serviceName, kSecAttrService, nil];
				
				NSArray *result = nil;
				status = SecItemCopyMatching((CFDictionaryRef)query, (CFTypeRef *)&result);
				
				NSCharacterSet *nonHexCharSet = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdefABCDEF"] invertedSet];
				
				if (status == noErr) {
					for (NSDictionary *item in result) {
						if (![[item objectForKey:kSecAttrService] isEqualToString:serviceName]) {
							continue;
						}
						
						NSString *fingerprint = [item objectForKey:kSecAttrAccount];
						if ([fingerprint length] < 8 || [fingerprint length] > 40) {
							continue;
						}
						if ([fingerprint rangeOfCharacterFromSet:nonHexCharSet].length > 0) {
							continue;
						}
						
						status = SecKeychainItemDelete((SecKeychainItemRef)[item objectForKey:kSecValueRef]);
						
						if (status != noErr) {
							success = NO;
							NSLog(@"Failed to delete keychain item: %@", SecCopyErrorMessageString(status, nil));
						}
					}
				}
				[result release];
				
			} else {
				SecKeychainItemRef keychainItem;
				
				NSSet *keys = [[GPGKeyManager sharedInstance] allKeysAndSubkeys];
				for (GPGKey *key in keys) {
					if (!key.secret) {
						continue;
					}
					
					NSString *accountName = [key fingerprint];
					status = SecKeychainFindGenericPassword(NULL, (UInt32)[serviceName length], [serviceName UTF8String], (UInt32)[accountName length], [accountName UTF8String], NULL, NULL, &keychainItem);
					if (status == errSecSuccess) {
						// Try to delete the keychain item.
						status = SecKeychainItemDelete(keychainItem);
						CFRelease(keychainItem);
						
						if (status != noErr) {
							success = NO;
							NSLog(@"Failed to delete old keychain item: %@", SecCopyErrorMessageString(status, nil));
						}
					}
				}
			}
			
		} @catch (NSException *exception) {
			success = NO;
			NSLog(@"deletePassphrases failed: %@", exception);
		}
		
		if (success) {
			localizedAlert(@"PassowrdsDeleted");
		} else {
			localizedAlert(@"PassowrdsDeletFailed");
		}
	}];
}



/*
 * Get and set the PassphraseCacheTime, with a dafault value of 600.
 */
- (NSInteger)passphraseCacheTime {
	NSNumber *value = [options valueInGPGAgentConfForKey:@"default-cache-ttl"];
	if (!value) {
		[options setValue:@(kDefaultPassphraseCacheTime) forKey:@"PassphraseCacheTime"];
		return kDefaultPassphraseCacheTime;
	}
	
	NSInteger intValue = value.integerValue;
	if (intValue == 0) {
		// default-cache-ttl is 0. This means no caching and the passphraseCacheTime field is disabled.
		// max-cache-ttl is used to remeber the value of default-cache-ttl when the field is disabled.
		intValue = [[options valueInGPGAgentConfForKey:@"max-cache-ttl"] integerValue];
	}
	
	return intValue;
}
- (void)setPassphraseCacheTime:(NSInteger)value {
	[options setValue:@(value) forKey:@"PassphraseCacheTime"];
}

- (BOOL)rememberPassword {
	NSNumber *value = [options valueInGPGAgentConfForKey:@"default-cache-ttl"];
	if (!value) {
		[options setValue:@(kDefaultPassphraseCacheTime) forKey:@"PassphraseCacheTime"];
		return YES;
	}
	
	NSInteger intValue = value.integerValue;
	if (intValue != 0) {
		return YES;
	}
	
	intValue = [[options valueInGPGAgentConfForKey:@"max-cache-ttl"] integerValue];
	
	return intValue == 0;
}
- (void)setRememberPassword:(BOOL)value {
	NSNumber *cacheTimeNumber = [options valueInGPGAgentConfForKey:@"default-cache-ttl"];
	NSInteger cacheTime = cacheTimeNumber.integerValue;
	if (!cacheTimeNumber) {
		cacheTime = kDefaultPassphraseCacheTime;
		[self setPassphraseCacheTime:kDefaultPassphraseCacheTime];
	}
	
	if (value) {
		if (cacheTime == 0) {
			NSInteger maxTime = [[options valueInGPGAgentConfForKey:@"max-cache-ttl"] integerValue];
			if (maxTime != 0) {
				[self setPassphraseCacheTime:maxTime];
			}
		}
	} else {
		if (cacheTime != 0) {
			[options setValueInGPGAgentConf:@0 forKey:@"default-cache-ttl"];
			[options setValueInGPGAgentConf:@(cacheTime) forKey:@"max-cache-ttl"];
		} else {
			NSInteger maxTime = [[options valueInGPGAgentConfForKey:@"max-cache-ttl"] integerValue];
			
			if (maxTime == 0) {
				[options setValueInGPGAgentConf:@0 forKey:@"default-cache-ttl"];
				[options setValueInGPGAgentConf:@(kDefaultPassphraseCacheTime) forKey:@"max-cache-ttl"];
			}
		}
		[options setValueInGPGAgentConf:@0 forKey:@"default-cache-ttl-ssh"];
		[options setValueInGPGAgentConf:@0 forKey:@"max-cache-ttl-ssh"];
	}
}


/*
 * Should pinentry save passwords in the macOS keychain by default?
 */
- (BOOL)useKeychain {
	return [self.options boolForKey:@"UseKeychain"] && ![self.options boolForKey:@"DisableKeychain"];
}
- (void)setUseKeychain:(BOOL)useKeychain {
	[self.options setBool:useKeychain forKey:@"UseKeychain"];
}


/*
 * Handle external key changes.
 */
- (void)keysDidChange:(NSNotification *)notification {
	[self willChangeValueForKey:@"secretKeys"];
	[secretKeysLock lock];
	[secretKeys release];
	secretKeys = nil;
	[secretKeysLock unlock];
	[self didChangeValueForKey:@"secretKeys"];
}


/*
 * Returns all usable secret keys.
 */
- (NSArray *)secretKeys {
	[secretKeysLock lock];
		
	if (!secretKeys) {
		NSSet *unsorted = [[GPGKeyManager sharedInstance].allKeys objectsPassingTest:^BOOL(GPGKey *key, BOOL *stop) {
			return key.secret && key.validity < GPGValidityInvalid;
		}];
		NSSortDescriptor *descriptor = [NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES selector:@selector(localizedCaseInsensitiveCompare:)];
		secretKeys = [unsorted sortedArrayUsingDescriptors:@[descriptor]];
		[secretKeys retain];
	}
	NSArray *value = [[secretKeys retain] autorelease];
	
	[secretKeysLock unlock];
	return value;
}



/*
 * The NSBundle for GPGPreferences.prefPane.
 */
- (NSBundle *)myBundle {
	if (!myBundle) {
		myBundle = [NSBundle bundleForClass:[self class]];
	}
	return myBundle;
}



/*
 * Give the credits from Credits.rtf.
 */
- (NSAttributedString *)credits {
	return [[[NSAttributedString alloc] initWithPath:[self.myBundle pathForResource:@"Credits" ofType:@"rtf"] documentAttributes:nil] autorelease];
}


/*
 * Does the user have at least one secret key?
 */
- (BOOL)haveSecretKeys {
	return self.secretKeys.count > 0;
}

/*
 * Array of readable descriptions of the secret keys.
 */
- (NSArray *)secretKeyDescriptions {
	NSArray *keys = self.secretKeys;
	if (keys.count == 0) {
		return @[@"No key found. Please create your first key with GPG Keychain."];
	}

	NSMutableArray *decriptions = [NSMutableArray array];
	for (GPGKey *key in keys) {
		[decriptions addObject:[NSString stringWithFormat:@"%@ – %@", key.userIDDescription, key.keyID.shortKeyID]];
	}
	return decriptions;
}

/*
 * Index of the default key.
 */
- (NSInteger)indexOfSelectedSecretKey {
	NSArray *keys = self.secretKeys;

	if (keys.count == 0) {
		return 0;
	}
	
	NSString *defaultKey = [options valueForKey:@"default-key"];
	NSInteger i, count = keys.count;
	if (defaultKey.length > 0) {
		for (i = 0; i < count; i++) {
			GPGKey *key = keys[i];
			if ([key.textForFilter rangeOfString:defaultKey options:NSCaseInsensitiveSearch].length > 0) {
				return i;
			}
		}
	}
	
	// No (valid) default key set.
	// Set the newest key as default.
	GPGKey *newestKey = nil;
	NSInteger index = 0;
	for (i = 0; i < count; i++) {
		GPGKey *key = keys[i];
		if (key.validity < GPGValidityInvalid) {
			if (newestKey == nil || [newestKey.creationDate isLessThan:key.creationDate]) {
				newestKey = key;
				index = i;
			}
		}
	}
	if (!newestKey) {
		newestKey = keys[0];
	}
	
	[options setValue:newestKey.fingerprint forKey:@"default-key"];
	
	return index;
}
- (void)setIndexOfSelectedSecretKey:(NSInteger)index {
	NSArray *keys = self.secretKeys;
	if (index < keys.count && index >= 0) {
		[options setValue:[keys[index] fingerprint] forKey:@"default-key"];
	}
}


/*
 * Keyserver
 */
- (NSArray *)keyservers {
    return options.keyservers;
}

- (NSString *)keyserver {
    return self.keyserverToCheck ? self.keyserverToCheck : options.keyserver;
}
- (void)setKeyserver:(NSString *)value {
	if (value.length == 0) {
		// Don't allow an empty keyserver. Set the default keyserver.
		self.keyserverToCheck = nil;
		self.options.keyserver = GPG_DEFAULT_KEYSERVER;
		[self performSelectorOnMainThread:@selector(setKeyserver:) withObject:GPG_DEFAULT_KEYSERVER waitUntilDone:NO];
	} else {
		self.keyserverToCheck = value;
	}
}

- (IBAction)testKeyserver:(id)sender {
	if (!self.keyserverToCheck) {
		return;
	}
	if (self.testingServer) {
		// Cancel the last check.
		[self.gpgc cancel];
	}
	
	[spinner startAnimation:nil];
	self.testingServer = YES;
	GPGController *gc = [GPGController gpgController];
	self.gpgc = gc;
	
	__block BOOL serverWorking = NO;
	__block BOOL keepCurrentServer = NO;
	dispatch_group_t dispatchGroup = dispatch_group_create();
	dispatch_group_enter(dispatchGroup);
	
	dispatch_group_notify(dispatchGroup, dispatch_get_main_queue(), ^{
		if (gc != self.gpgc) {
			// This is not the result of the last check.
			return;
		}
		self.gpgc = nil;
		self.testingServer = NO;
		
		if (!keepCurrentServer) {
			if (serverWorking) {
				// The server passed the check.
				// Set it as default keyserver.
				self.options.keyserver = gc.keyserver;
			} else {
				[self.options removeKeyserver:gc.keyserver];
				localizedAlert(@"BadKeyserver");
			}
		}
		
		self.keyserverToCheck = nil;
	});
	
	// We can't use options.keyserver anymore, since setting this value
	// will update gpg.conf which doesn't make sense if the keyserver can't be used.
	self.gpgc.keyserver = self.keyserverToCheck;
	dispatch_group_enter(dispatchGroup);
	[self.gpgc testKeyserverWithCompletionHandler:^(BOOL working) {
		serverWorking = working;
		dispatch_group_leave(dispatchGroup);
	}];
	
	
	if ([GPGOptions sharedOptions].isVerifyingKeyserver && ![GPGOptions isVerifyingKeyserver:self.keyserverToCheck]) {
		// The user is switching from keys.openpgp.org to an old keyserver. Better warn them.
		[gpgPrefPane showAlertWithTitle:localizedLibmacgpgString(@"SwitchToOldKeyserver_Title")
								message:localizedLibmacgpgString(@"SwitchToOldKeyserver_Msg")
								buttons:@[localizedLibmacgpgString(@"SwitchToOldKeyserver_No"), localizedLibmacgpgString(@"SwitchToOldKeyserver_Yes")]
							   checkbox:nil
					  completionHandler:^(NSModalResponse returnCode) {
						  if (returnCode == NSAlertFirstButtonReturn) {
							  // Do not change the server.
							  keepCurrentServer = YES;
							  [self.gpgc cancel];
						  }

						  dispatch_group_leave(dispatchGroup);
		}];
	} else {
		dispatch_group_leave(dispatchGroup);
	}
	
}




/*
 * Crash reporting
 */
- (BOOL)automaticallySendCrashReports {
	return [updaterOptions boolForKey:AutomaticallySendCrashReportsKey];
}
- (void)setAutomaticallySendCrashReports:(BOOL)value {
	if (value == NO) {
		changingUserEmailEnabled = YES;
		[prefPane.mainView.window endEditingFor:nil];
		changingUserEmailEnabled = NO;
	}
	[updaterOptions setBool:value forKey:AutomaticallySendCrashReportsKey];
}

- (NSString *)crashReportsUserEmail {
	return [updaterOptions valueForKey:CrashReportsUserEmailKey];
}
- (void)setCrashReportsUserEmail:(NSString *)value {
	crashReportsUserEmail = value;
	if (allowUserEmailContact > 0) {
		[updaterOptions setValue:value forKey:CrashReportsUserEmailKey];
	}
}
- (BOOL)allowUserEmailContact {
	if (allowUserEmailContact == 0) {
		if ([updaterOptions valueForKey:CrashReportsUserEmailKey]) {
			allowUserEmailContact = 1;
		} else {
			allowUserEmailContact = -1;
		}
	}
	return allowUserEmailContact > 0;
}
- (void)setAllowUserEmailContact:(BOOL)value {
	if (value) {
		allowUserEmailContact = 1;
		[updaterOptions setObject:crashReportsUserEmail forKey:CrashReportsUserEmailKey];
	} else {
		allowUserEmailContact = -1;
		changingUserEmailEnabled = YES;
		[prefPane.mainView.window endEditingFor:nil];
		changingUserEmailEnabled = NO;
		[updaterOptions setObject:nil forKey:CrashReportsUserEmailKey];
	}
}

- (BOOL)validateCrashReportsUserEmail:(inout id *)ioValue error:(out NSError **)outError {
	NSString *value = *ioValue;
	if (value == nil) {
		return YES;
	}

	NSString *errorText = nil;
	
	NSString * const tooLongKey = @"EmailCheck_TooLong";
	NSString * const invalidKey = @"EmailCheck_Invalid";

	
	if (![value isKindOfClass:[NSString class]]) {
		errorText = invalidKey;
	} else if (value.length > 254) {
		errorText = tooLongKey;
	} else if ([value hasPrefix:@"@"] || [value hasSuffix:@"@"] || [value hasSuffix:@"."]) {
		errorText = invalidKey;
	} else {
		NSArray *components = [value componentsSeparatedByString:@"@"];
		if (components.count != 2) {
			errorText = invalidKey;
		} else {
			NSString *localPart = components[0];
			NSString *globalPart = components[1];
			NSMutableCharacterSet *charSet = [NSMutableCharacterSet characterSetWithRange:(NSRange){128, 65408}];
			[charSet addCharactersInString:@"01234567890_-+@.abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"];
			[charSet invert];
			
			if (localPart.length > 64) {
				errorText = invalidKey;
			} else if ([localPart rangeOfCharacterFromSet:charSet].length != 0) {
				errorText = invalidKey;
			} else {
				[charSet addCharactersInString:@"+"];
				if ([globalPart rangeOfCharacterFromSet:charSet].length != 0) {
					errorText = invalidKey;
				}
			}
		}
	}
	
	if (errorText) {
		if (changingUserEmailEnabled) {
			*ioValue = crashReportsUserEmail;
			return YES;
		} else {
			if (outError) {
				NSDictionary *userInfo = @{NSLocalizedDescriptionKey: localized(errorText), NSLocalizedRecoverySuggestionErrorKey: localized(@"EmailCheck_Msg")};
				*outError = [NSError errorWithDomain:@"GPGPreferencesErrorDomain" code:1 userInfo:userInfo];
			}
			return NO;

		}
	}
	
	return YES;
}





#pragma mark Button Links

- (IBAction)openSupport:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://gpgtools.tenderapp.com/"]];
}

- (IBAction)openKnowledgeBase:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://gpgtools.tenderapp.com/kb"]];
}




#pragma mark Version infos

- (NSString *)versionDescription {
	return [NSString stringWithFormat:[self.myBundle localizedStringForKey:@"VERSION: %@" value:nil table:nil], [self version]];
}

- (NSString *)buildNumberDescription {
    return [NSString stringWithFormat:[self.myBundle localizedStringForKey:@"BUILD: %@" value:nil table:nil], [self bundleVersion]];
}

- (NSString *)version {
	return [self.myBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
}

- (NSString *)bundleVersion {
	return [self.myBundle objectForInfoDictionaryKey:@"CFBundleVersion"];
}



@end
