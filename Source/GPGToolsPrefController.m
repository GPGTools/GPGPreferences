//
//  UpdateButton.m
//  GPGTools
//
//  Created by Alexander Willner on 04.08.10.
//  Edited by Roman Zechmeister 11.07.2011
//  Copyright 2010 GPGTools Project Team. All rights reserved.
//

#import "GPGToolsPrefController.h"
#import <Security/Security.h>
#import <Security/SecItem.h>

#define GPG_SERVICE_NAME "GnuPG"

static NSString * const kKeyserver = @"keyserver";
static NSUInteger const kDefaultPassphraseCacheTime = 600;

@interface GPGToolsPrefController ()
@property (readwrite) BOOL testingServer;
@end


@implementation NSArray (For106)

- (id)objectAtIndexedSubscript:(NSUInteger)idx {
	return [self objectAtIndex:idx];
}

@end




@implementation GPGToolsPrefController
@synthesize options, testingServer;

- (id)init {
	if (!(self = [super init])) {
		return nil;
	}
	secretKeysLock = [[NSLock alloc] init];
	
	options = [GPGOptions sharedOptions];
	options.standardDomain = @"org.gpgtools.gpgpreferences";
	[[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(keysDidChange:) name:GPGKeyManagerKeysDidChangeNotification object:nil];
	[[GPGKeyManager sharedInstance] loadAllKeys];

	return self;
}
- (void)dealloc {
	[secretKeysLock release];
	[options release];
	[super dealloc];
}


- (NSString *)comments {
	return [[options valueInGPGConfForKey:@"comment"] componentsJoinedByString:@"\n"];
}
- (void)setComments:(NSString *)value {
	NSArray *lines = [value componentsSeparatedByString:@"\n"];
	NSMutableArray *filteredLines = [NSMutableArray array];
	NSCharacterSet *whitespaceCharacterSet = [NSCharacterSet whitespaceCharacterSet];
	NSCharacterSet *nonWhitespaceCharacterSet = [whitespaceCharacterSet invertedSet];
	
	[lines enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		if ([obj rangeOfCharacterFromSet:nonWhitespaceCharacterSet].length > 0) {
			[filteredLines addObject:[obj stringByTrimmingCharactersInSet:whitespaceCharacterSet]];
		}
	}];
	
	
	[options setValueInGPGConf:filteredLines forKey:@"comment"];
}

- (void)setNilValueForKey:(NSString *)key {
    if([key isEqualToString:@"passphraseCacheTime"]) {
        [self setPassphraseCacheTime:kDefaultPassphraseCacheTime];
        return;
    }
}

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key {
	NSSet *mySet = nil;
	NSSet *keysAffectedBySecretKeys = [NSSet setWithObjects:@"secretKeyDescriptions", @"indexOfSelectedSecretKey", nil];
	if ([keysAffectedBySecretKeys containsObject:key]) {
		mySet = [NSSet setWithObject:@"secretKeys"];
	}
	NSSet *superSet = [super keyPathsForValuesAffectingValueForKey:key];
	return [superSet setByAddingObjectsFromSet:mySet];
}


/*
 * Delete stored passphrases from the Mac OS X keychain.
 */
- (IBAction)deletePassphrases:(id)sender {
	@try {
		[options gpgAgentFlush];
		
        // On 10.6 and lower the newer SecItemCopyMatching API is available, but generic passwords
        // can't be searched. So on 10.7+ we'll use the newer API, while on 10.6 we fallback to the
        // SecKeychainFindGenericPassword method, which is not quite as handy, since it requires us to know
        // the accountName (which is the fingerprint of the key in our case).
        NSString *serviceName = @"GnuPG";
        if(floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_6) {
            NSDictionary *query = [NSDictionary dictionaryWithObjectsAndKeys:kSecClassGenericPassword, kSecClass, kSecMatchLimitAll, kSecMatchLimit, kCFBooleanTrue, kSecReturnRef, kCFBooleanTrue, kSecReturnAttributes, serviceName, kSecAttrService, nil];

            NSArray *result = nil;
            OSStatus status = SecItemCopyMatching((CFDictionaryRef)query, (CFTypeRef *)&result);

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
                    if (status) {
                        NSLog(@"ERROR %i: %@", (int)status, SecCopyErrorMessageString(status, nil));
                    }
                }
            }

            [result release];
        }
        else {
            SecKeychainItemRef keychainItem;

            NSSet *keys = [[GPGKeyManager sharedInstance] allKeysAndSubkeys];
            for(GPGKey *key in keys) {
                if(!key.secret)
                    continue;

                NSString *accountName = [key fingerprint];
                OSStatus status = SecKeychainFindGenericPassword(NULL, [serviceName length], [serviceName UTF8String], [accountName length], [accountName UTF8String], NULL, NULL, &keychainItem);
                if(status == errSecSuccess) {
                    // Try to delete the keychain item.
                    status = SecKeychainItemDelete(keychainItem);
                    CFRelease(keychainItem);
                    keychainItem = NULL;
                    if(status != errSecSuccess)
                        NSLog(@"Failed to delete keychain item: %@", SecCopyErrorMessageString(status, NULL));
                }
            }
        }
	} @catch (NSException *exception) {
		NSLog(@"deletePassphrases failed: %@", exception);
	}
}



/*
 * Get and set the PassphraseCacheTime, with a dafault value of 600.
 */
- (NSInteger)passphraseCacheTime {
	NSNumber *value = [options valueForKey:@"PassphraseCacheTime"];
	if (!value) {
		[self setPassphraseCacheTime:kDefaultPassphraseCacheTime];
		return kDefaultPassphraseCacheTime;
	}
	return [value integerValue];
}
- (void)setPassphraseCacheTime:(NSInteger)value {
	[options setValue:[NSNumber numberWithInteger:value] forKey:@"PassphraseCacheTime"];
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
		secretKeys = [[[[GPGKeyManager sharedInstance].allKeys objectsPassingTest:^BOOL(GPGKey *key, BOOL *stop) {
			return key.secret && key.validity < GPGValidityInvalid;
		}] allObjects] retain];
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
    return [options keyservers];
}

- (NSString *)keyserver {
    return keyserverToCheck ? [[keyserverToCheck retain] autorelease] : [options valueForKey:kKeyserver];
}
- (void)setKeyserver:(NSString *)value {
	if (value != keyserverToCheck) {
		NSString *oldValue = keyserverToCheck;
		keyserverToCheck = [value retain];
		[oldValue release];
	}
}

- (IBAction)testKeyserver:(id)sender {
	if (self.testingServer) {
		[gpgc cancel];
	}
	
	// We can't use options.keyserver anymore, since setting this value
	// will update gpg.conf which doesn't make sense if the keyserver can't be used.
	gpgc = [GPGController gpgController];
	gpgc.keyserver = keyserverToCheck;
	gpgc.async = YES;
	gpgc.delegate = self;
	gpgc.keyserverTimeout = 3;
	gpgc.timeout = 3;
	[spinner startAnimation:nil];
	self.testingServer = YES;
	
	[gpgc testKeyserver];
}

- (void)gpgController:(GPGController *)gc operationDidFinishWithReturnValue:(id)value {
	// Result of the keyserer test.
	self.testingServer = NO;
	
	if (![value boolValue]) {
		[self.options removeKeyserver:gc.keyserver];
		
		dispatch_async(dispatch_get_main_queue(), ^{
			WarningPanel(localized(@"BadKeyserver_Title"), localized(@"BadKeyserver_Msg"));
		});
		
	}
	else {
		// The server passed the check.
		// Set it as default keyserver.
		options.keyserver = gc.keyserver;
	}
}


+ (NSSet *)keyPathsForValuesAffectingKeyservers {
	return [NSSet setWithObject:@"options.keyservers"];
}
+ (NSSet *)keyPathsForValuesAffectingKeyserver {
	return [NSSet setWithObject:@"options.keyserver"];
}

- (IBAction)removeKeyserver:(id)sender {
	NSString *oldServer = self.keyserver;
	[self.options removeKeyserver:oldServer];
	NSArray *servers = self.keyservers;
	if (servers.count > 0) {
		if (![servers containsObject:oldServer]) {
			self.keyserver = [self.keyservers objectAtIndex:0];
		}
	} else {
		self.keyserver = @"";
	}
}



- (BOOL)autoKeyRetrive {
	NSArray *keyserverOptions = [self.options valueInGPGConfForKey:@"keyserver-options"];
	return [keyserverOptions containsObject:@"auto-key-retrieve"];
}
- (void)setAutoKeyRetrive:(BOOL)value {
	NSMutableArray *keyserverOptions = [[self.options valueInGPGConfForKey:@"keyserver-options"] mutableCopy];
	if (!keyserverOptions) {
		keyserverOptions = [NSMutableArray array];
	}
	
	if (value) {
		[keyserverOptions removeObject:@"no-auto-key-retrieve"];
		if (![keyserverOptions containsObject:@"auto-key-retrieve"]) {
			[keyserverOptions addObject:@"auto-key-retrieve"];
		}
	} else {
		[keyserverOptions removeObject:@"auto-key-retrieve"];
	}
	
	[self.options setValueInGPGConf:keyserverOptions forKey:@"keyserver-options"];
}


#pragma mark Button Links

- (IBAction)openSupport:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://gpgtools.tenderapp.com/"]];
}

- (IBAction)openDonate:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://gpgtools.org/donate"]];
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
