#import "GPGDebugCollector.h"
#import "GPGPVersionInfo.h"
#import <Libmacgpg/Libmacgpg.h>
#import <sys/socket.h>
#import <sys/un.h>


@interface NoRealClass
+ (NSString *)GPGPath;
+ (NSString *)pinentryPath;
@end


@implementation GPGDebugCollector



// Returns all debug infos as JSON.
- (NSString *)debugInfosJSON {
	NSDictionary *debugInfos = self.debugInfos;
	NSError *error = nil;
	NSData *data = [NSJSONSerialization dataWithJSONObject:debugInfos options:0 error:&error];
	if (!data) {
		data = [NSJSONSerialization dataWithJSONObject:@{@"error": error.debugDescription}
											   options:0
												 error:nil];
	}
	return data.gpgString;
}

// Returns all debug infos in a dictionary.
- (NSDictionary *)debugInfos {
	[self collectAllDebugInfo];
	NSDictionary *cleanDebugInfos = [self plistDictionary:debugInfos];
	return [[cleanDebugInfos copy] autorelease];
}



- (void)collectAllDebugInfo {
	// Calls all the other methods.
	@try {
		[self collectVersions];
	} @catch (NSException *exception) {}
	@try {
		[self collectEnvironment];
	} @catch (NSException *exception) {}
	@try {
		[self collectFileInfos];
	} @catch (NSException *exception) {}
	@try {
		[self collectFileContents];
	} @catch (NSException *exception) {}
	@try {
		[self collectBinaryPaths];
	} @catch (NSException *exception) {}
	@try {
		[self collectBinaryVersions];
	} @catch (NSException *exception) {}
	@try {
		[self collectAgentInfos];
	} @catch (NSException *exception) {}
	@try {
		[self collectMailBundleConfig];
	} @catch (NSException *exception) {}
	@try {
		[self collectKeyListings];
	} @catch (NSException *exception) {}
	@try {
		[self testEncryptAndSign];
	} @catch (NSException *exception) {}
	@try {
		[self collectMailAccounts];
	} @catch (NSException *exception) {}
	
	@try {
		// Must be last.
		[self collectInfosForPaths];
	} @catch (NSException *exception) {}
}

- (void)testEncryptAndSign {
	// Test encryption and signing.
	NSString *gpgPath = debugInfos[@"paths"][@"gpg"];
	if (gpgPath == nil) {
		return;
	}
	
	NSMutableDictionary *results = [NSMutableDictionary dictionary];
	
	results[@"encrypt_gpgtools"] = [self.class shellCommandOutput:[NSString stringWithFormat:@"'%@' --batch --trust-model always --no-tty -aer 85E38F69046B44C1EC9FB07B76D78F0500D026C4 <<<'Encrypted content'", gpgPath]];
	results[@"encrypt_self"] = [self.class shellCommandOutput:[NSString stringWithFormat:@"'%@' --batch --trust-model always --no-tty -ae --default-recipient-self <<<'Encrypted content'", gpgPath]];
	results[@"encrypt_decrypt"] = [self.class shellCommandOutput:[NSString stringWithFormat:@"'%@' --batch --trust-model always --no-tty -ae --default-recipient-self <<<'Encrypted content' | '%@'  --batch --no-tty -d", gpgPath, gpgPath]];

	results[@"sign"] = [self.class shellCommandOutput:[NSString stringWithFormat:@"'%@' --batch --trust-model always --no-tty -as <<<'Signed content'", gpgPath]];
	results[@"sign_and_encrypt"] = [self.class shellCommandOutput:[NSString stringWithFormat:@"'%@' --batch --trust-model always --no-tty -aser 85E38F69046B44C1EC9FB07B76D78F0500D026C4 --default-recipient-self <<<'Signed and encrypted content'", gpgPath]];

	
	debugInfos[@"encrypt_sign"] = results;
}

- (void)collectKeyListings {
	// List of user's keys.
	NSString *gpgPath = debugInfos[@"paths"][@"gpg"];
	if (gpgPath == nil) {
		return;
	}
	
	NSMutableDictionary *listings = [NSMutableDictionary dictionary];

	listings[@"public"] = [self.class commandOutput:@[gpgPath, @"--with-subkey-fingerprint", @"--with-keygrip", @"-k"]];
	listings[@"secret"] = [self.class commandOutput:@[gpgPath, @"--with-subkey-fingerprint", @"--with-keygrip", @"-K"]];
	
	debugInfos[@"key_listings"] = listings;
}

- (void)collectMailBundleConfig {
	// Are Mail bundles enabled?
	NSMutableDictionary *bundleConfig = [NSMutableDictionary dictionary];

	bundleConfig[@"enable_bundles"] = [self.class shellCommandOutput:@"defaults read com.apple.mail EnableBundles"];
	bundleConfig[@"bundle_compatibility_version"] = [self.class shellCommandOutput:@"defaults read com.apple.mail BundleCompatibilityVersion"];
	
	debugInfos[@"bundle_config"] = bundleConfig;
}

- (void)collectAgentInfos {
	// Test if the agent is running correctly.
	NSMutableDictionary *agentInfos = [NSMutableDictionary dictionary];
	
	agentInfos[@"normal_call"] = [self.class shellCommandOutput:@"gpg-agent"];
	agentInfos[@"direct_call"] = [self.class commandOutput:@[@"/usr/local/MacGPG2/bin/gpg-agent"]];
	agentInfos[@"ps"] = [self.class shellCommandOutput:@"ps axo command | grep '[g]pg-agent'"];

	debugInfos[@"agent_infos"] = agentInfos;
}

- (void)collectBinaryPaths {
	// Find gpg, gpg2, gpg-agent and pinetry binaries.
	NSMutableDictionary *paths = [NSMutableDictionary dictionary];
	Class GPGTaskHelperClass = NSClassFromString(@"GPGTaskHelper");
	if (GPGTaskHelperClass) {
		if ([GPGTaskHelperClass respondsToSelector:@selector(GPGPath)]) {
			NSString *gpgPath = [GPGTaskHelperClass GPGPath];
			paths[@"gpg"] = gpgPath;
		}
		if ([GPGTaskHelperClass respondsToSelector:@selector(pinentryPath)]) {
			NSString *pinentryPath = [GPGTaskHelperClass pinentryPath];
			paths[@"pinentry"] = pinentryPath;
		}
	}
	GPGOptions *options = [GPGOptions sharedOptions];
	if ([options respondsToSelector:@selector(pinentryPath)]) {
		paths[@"pinentry"] = options.pinentryPath;
	}

	paths[@"gnupg"] = [self.class runShellCommand:@"which -a gpg gpg2"];
	paths[@"agent"] = [self.class runShellCommand:@"which -a gpg-agent"];
	
	debugInfos[@"paths"] = paths;
}

- (void)collectBinaryVersions {
	// Versions of all binaries found by collectBinaryPaths.
	NSDictionary *allPaths = debugInfos[@"paths"];
	NSMutableSet *binaries = [NSMutableSet set];
	
	if (allPaths[@"gnupg"]) {
		[binaries addObjectsFromArray:[self linesFromString:allPaths[@"gnupg"]]];
	}
	if (allPaths[@"agent"]) {
		[binaries addObjectsFromArray:[self linesFromString:allPaths[@"agent"]]];
	}
	if (allPaths[@"gpg"]) {
		[binaries addObject:allPaths[@"gpg"]];
	}
	if (allPaths[@"pinentry"]) {
		[binaries addObject:allPaths[@"pinentry"]];
	}
	
	NSMutableDictionary *versions = [NSMutableDictionary dictionary];
	
	for (NSString *binary in binaries) {
		NSString *string = [self.class runCommand:@[binary, @"--version"]];
		if (string == nil) {
			string = @"";
		}
		versions[binary] = string;
		[self addPathToCollect:binary maxLinkDepth:3 category:@"gpg"];
	}
	
	debugInfos[@"binary_versions"] = versions;
}

- (void)collectVersions {
	debugInfos[@"versions"] = [GPGPVersionInfo sharedInstance].versionInfo;
}


- (void)collectEnvironment {
	// All environment variables.
	NSMutableDictionary *environment = [NSMutableDictionary dictionary];
	
	environment[@"environment"] = [[NSProcessInfo processInfo] environment];
	environment[@"shell_environment"] = [self.class shellCommandOutput:@"printenv"];
	environment[@"mount"] = [self.class commandOutput:@[@"/sbin/mount"]];
	
	debugInfos[@"environment"] = environment;
}



- (void)collectFileContents {
	// Content of files and responses from sockets.
	
	NSDictionary *files = @{
		@"gpg_config_files": @[
			@"$GNUPGHOME/S.gpg-agent",
			@"$GNUPGHOME/gpg.conf",
			@"$GNUPGHOME/gpg-agent.conf",
			@"$GNUPGHOME/scdaemon.conf",
			@"$GNUPGHOME/dirmngr.conf",
		],
		@"gpg_suite_config_files": @[
			@"~/Library/Preferences/org.gpgtools.common.plist",
			@"~/Library/Preferences/org.gpgtools.gpgkeychainaccess.plist",
			@"~/Library/Preferences/org.gpgtools.gpgmail.plist",
			@"~/Library/Preferences/org.gpgtools.updater.plist",
			@"/Library/Preferences/org.gpgtools.common.plist",
			@"/Library/Preferences/org.gpgtools.gpgkeychainaccess.plist",
			@"/Library/Preferences/org.gpgtools.gpgmail.plist",
			@"/Library/Preferences/org.gpgtools.updater.plist",
			@"/Library/LaunchAgents/org.gpgtools.Libmacgpg.xpc.plist",
			@"/Library/LaunchAgents/org.gpgtools.gpgmail.enable-bundles.plist",
			@"/Library/LaunchAgents/org.gpgtools.gpgmail.patch-uuid-user.plist",
			@"/Library/LaunchAgents/org.gpgtools.macgpg2.fix.plist",
			@"/Library/LaunchAgents/org.gpgtools.macgpg2.shutdown-gpg-agent.plist",
			@"/Library/LaunchAgents/org.gpgtools.updater.plist"
		],
		@"other_files": @[
			@"~/Library/Mail/V2/MailData/Accounts.plist",
			@"~/Library/Mail/V3/MailData/Accounts.plist",
			@"~/Library/Mail/V4/MailData/Accounts.plist",
			@"~/Library/Mail/V5/MailData/Accounts.plist",
		]
	};
	for (NSString *category in files) {
		for (NSString *path in files[category]) {
			NSString *expandedPath = [self expand:path];
			[self collectContentOfFile:expandedPath category:category];
		}
	}
}

- (id)contentOfFile:(NSString *)file {
	if ([[file substringWithRange:NSMakeRange(file.length - 6, 6)] isEqualToString:@".plist"]) {
		NSDictionary *content = [NSDictionary dictionaryWithContentsOfFile:file];
		if (content) {
			return content;
		}
	}
	
	const char *path = file.UTF8String;
	NSUInteger length = [file lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
	int fd = -1;
	
	fd = open(path, O_RDONLY);
	if (fd < 0) {
		if (errno != EOPNOTSUPP) {
			if (errno == ENOENT) {
				// No such file or directory.
				return nil;
			}
			return [NSString stringWithFormat:@"Error: %s", strerror(errno)];
		}
		
		// It's a socket.
		struct sockaddr_un socketAddress;
		
		if (length >= sizeof(socketAddress.sun_path)) {
			return [NSString stringWithFormat:@"Error: %s", strerror(ENAMETOOLONG)];
		}
		
		fd = socket(AF_UNIX, SOCK_STREAM, 0);
		if (fd < 0) {
			return [NSString stringWithFormat:@"Error: %s", strerror(errno)];
		}
		socketAddress.sun_family = AF_UNIX;
		strlcpy(socketAddress.sun_path, path, sizeof(socketAddress.sun_path));
		length = offsetof(struct sockaddr_un, sun_path[length+1]);
		
		if (connect(fd, (void *)&socketAddress, (socklen_t)length) < 0) {
			close(fd);
			return [NSString stringWithFormat:@"Error: %s", strerror(errno)];
		}
		shutdown(fd, SHUT_WR);
	}
	
	
	NSFileHandle *fileHandle = [[NSFileHandle alloc] initWithFileDescriptor:fd closeOnDealloc:YES];
	NSData *data = [fileHandle readDataToEndOfFile];
	[fileHandle release];
	
	return data.gpgString;
}

- (void)collectContentOfFile:(NSString *)file category:(NSString *)category {
	id content = [self contentOfFile:file];
	
	if (content) {
		if (debugInfos[@"file_contents"] == nil) {
			debugInfos[@"file_contents"] = [NSMutableDictionary dictionary];
		}
		if (debugInfos[@"file_contents"][category] == nil) {
			debugInfos[@"file_contents"][category] = [NSMutableDictionary dictionary];
		}

		debugInfos[@"file_contents"][category][file] = content;
	}
}



- (void)collectFileInfos {
	// Attributes of files and folders.
	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	NSDictionary *paths = @{
		@"gpg_suite": @[
			@"/Applications/GPG Keychain.app",
			@"/Applications/GPG Keychain Access.app",
			
			@"/Library/Services",
			@"/Library/Services/GPGServices.service",
			@"~/Library/Services",
			@"~/Library/Services/GPGServices.service",
			
			@"/Library/PreferencePanes/GPGPreferences.prefPane",
			@"~/Library/PreferencePanes/GPGPreferences.prefPane",
			
			@"/Library/Frameworks/Libmacgpg.framework",
			@"~/Library/Frameworks/Libmacgpg.framework",
			
			@"/Library/Application Support/GPGTools",
			@"/Library/Application Support/GPGTools/*",
			@"~/Library/Application Support/GPGTools",
			@"~/Library/Application Support/GPGTools/*"
		],
		@"gpg_suite_config": @[
			@"/Library/LaunchAgents/org.gpgtools.macgpg2.gpg-agent.plist",
			@"~/Library/LaunchAgents/org.gpgtools.macgpg2.gpg-agent.plist",
			
			@"/Library/LaunchAgents/org.gpgtools.Libmacgpg.xpc.plist",
			@"/Library/LaunchAgents/org.gpgtools.gpgmail.enable-bundles.plist",
			@"/Library/LaunchAgents/org.gpgtools.gpgmail.patch-uuid-user.plist",
			@"/Library/LaunchAgents/org.gpgtools.macgpg2.fix.plist",
			@"/Library/LaunchAgents/org.gpgtools.macgpg2.shutdown-gpg-agent.plist",
			@"/Library/LaunchAgents/org.gpgtools.updater.plist"
		],
		@"gpg": @[
			@"/usr/local",
			@"/usr/local/MacGPG1",
			@"/usr/local/MacGPG2",
			@"/usr/local/MacGPG2/bin/gpg2",
			@"/usr/local/MacGPG2/libexec/pinentry-mac.app",
			
			@"$GNUPGHOME",
			@"$GNUPGHOME/*",
			@"$GNUPGHOME/private-keys-v1.d/*"
		],
		@"mail": @[
			@"/Library/Mail/Bundles/*",
			@"~/Library/Mail/Bundles/*",
			@"/Network/Library/Mail/Bundles/*",
			
			
			@"~/Library/Accounts",
			@"~/Library/Accounts/*"
		]
	};
	
	for (NSString *category in paths) {
		for (NSString *path in paths[category]) {
			NSString *expandedPath = [self expand:path];
			if ([[expandedPath substringWithRange:NSMakeRange(expandedPath.length - 2, 2)] isEqualToString:@"/*"]) {
				NSString *dir = [expandedPath substringWithRange:NSMakeRange(0, expandedPath.length - 2)];
				[self addPathToCollect:dir maxLinkDepth:3 category:category];
				
				for (NSString *filename in [fileManager contentsOfDirectoryAtPath:dir error:nil]) {
					if ([filename isEqualToString:@".DS_Store"]) {
						continue;
					}
					expandedPath = [dir stringByAppendingPathComponent:filename];
					[self addPathToCollect:expandedPath maxLinkDepth:3 category:category];
				}
			} else {
				[self addPathToCollect:expandedPath maxLinkDepth:3 category:category];
			}
		}
	}
}

- (void)addPathToCollect:(NSString *)path maxLinkDepth:(NSInteger)depth category:(NSString *)category {
	if (!_pathsToCollect) {
		_pathsToCollect = [[NSMutableDictionary alloc] init];
	}
	if (!_pathsToCollect[category]) {
		_pathsToCollect[category] = [NSMutableArray array];
	}
	if ([_pathsToCollect[category] containsObject:path]) {
		// Info for path already collected.
		return;
	}
	
	NSFileManager *fileManager = [NSFileManager defaultManager];
	if ([fileManager fileExistsAtPath:path] == NO) {
		return;
	}
	
	[_pathsToCollect[category] addObject:path];
	
	if (depth > 0) {
		// Follow a possible symlink.
		NSDictionary *attributes = [fileManager attributesOfItemAtPath:path error:nil];
		if ([attributes[NSFileType] isEqualToString:NSFileTypeSymbolicLink]) {
			NSString *linkDestination = [fileManager destinationOfSymbolicLinkAtPath:path error:nil];
			if (linkDestination) {
				[self addPathToCollect:linkDestination maxLinkDepth:depth - 1 category:category];
			}
		}
	}
}
- (void)collectInfosForPaths {
	debugInfos[@"file_infos"] = [NSMutableDictionary dictionary];
	
	for (NSString *category in _pathsToCollect) {
		NSArray *paths = [_pathsToCollect[category] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
		NSArray *command = [@[@"/bin/ls", @"-hle@Od"] arrayByAddingObjectsFromArray:paths];
		NSString *fileInfos = [[self class] runCommand:command];
		debugInfos[@"file_infos"][category] = fileInfos;
	}
}


- (void)collectMailAccounts {
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSString *libraryPath = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES)[0];
	NSString *accountsDir = [libraryPath stringByAppendingPathComponent:@"Accounts"];
	NSArray *files = [fileManager contentsOfDirectoryAtPath:accountsDir error:nil];
	
	NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^Accounts\\d+\\.sqlite$" options:0 error:nil];
	for (NSString *file in files) {
		if ([regex firstMatchInString:file options:0 range:NSMakeRange(0, file.length)]) {
			[self collectAccountsFromPath:[accountsDir stringByAppendingPathComponent:file]];
		}
	}
}
- (void)collectAccountsFromPath:(NSString *)path {
	NSMutableArray *emailAliases = [NSMutableArray array];

	@try {
		NSError *error = nil;
		
		NSURL *accountsURL = [NSURL fileURLWithPath:path];
		NSURL *modelURL = [NSURL fileURLWithPath:@"/System/Library/PrivateFrameworks/AccountsDaemon.framework/Resources/accounts.momd"];
		
		
		NSManagedObjectModel *objectModel = [[[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL] autorelease];
		NSPersistentStoreCoordinator *coordinator = [[[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:objectModel] autorelease];
		
		
		NSDictionary *options = @{NSReadOnlyPersistentStoreOption: @YES};
		NSPersistentStore *store = [coordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:accountsURL options:options error:&error];
		if (!store) {
			NSLog(@"Failed to initalize persistent store: %@\n%@", error.localizedDescription, error.userInfo);
			return;
		}
		
		
		NSManagedObjectContext *context = [[[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType] autorelease];
		context.persistentStoreCoordinator = coordinator;
		
		
		NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"Account"];
		NSArray *accounts = [context executeFetchRequest:fetchRequest error:&error];
		if (error) {
			NSLog(@"Failed to execute fetch request: %@\n%@", error.localizedDescription, error.userInfo);
			return;
		}
		
		
		for (NSManagedObject *account in accounts) {
			NSSet *accountProperties = [account valueForKey:@"customProperties"];
			
			for (NSManagedObject *accountProperty in accountProperties) {
				NSString *key = [accountProperty valueForKey:@"key"];
				
				if ([key isEqualToString:@"EmailAliases"]) {
					NSArray *aliases = [accountProperty valueForKey:@"value"];
					[emailAliases addObjectsFromArray:aliases];
				}
			}
		}
	} @catch (NSException *exception) {
		NSLog(@"Exception in collectMailAccounts: %@", exception);
		return;
	}
	
	if (debugInfos[@"mail_accounts"] == nil) {
		debugInfos[@"mail_accounts"] = [NSMutableDictionary dictionary];
	}
	
	
	debugInfos[@"mail_accounts"][path] = [emailAliases.copy autorelease];
}




- (NSArray *)linesFromString:(NSString *)string {
	NSArray *components = [string componentsSeparatedByString:@"\n"];
	NSArray *lines = [components filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"length > 0"]];
	return lines;
}

+ (NSString *)runShellCommand:(NSString *)command {
	if (command == nil) {
		return @"";
	}
	return [self runCommand:[@[@"/bin/bash", @"-l", @"-c"] arrayByAddingObject:command]];
}
+ (NSString *)runCommand:(NSArray *)command {
	if (command.count == 0) {
		return @"";
	}
	@try {
		NSTask *task = [[[NSTask alloc] init] autorelease];
		NSPipe *pipe = [NSPipe pipe];
		task.standardOutput = pipe;
		task.standardError = pipe;
		task.launchPath = command[0];
		task.environment = @{@"LANG": @"C"};
		
		if (command.count > 1) {
			task.arguments = [command subarrayWithRange:NSMakeRange(1, command.count - 1)];
		}
		[task launch];
		NSString *string = [[[pipe fileHandleForReading] readDataToEndOfFile] gpgString];
		if (string == nil) {
			string = @"";
		}
		string = [string stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
		if (!string) {
			string = @"";
		}
		return string;
	}
	@catch (NSException *exception) {
		return [NSString stringWithFormat:@"Error: %@", exception.description];
	}
}

+ (NSDictionary *)shellCommandOutput:(NSString *)command {
	NSString *output = [self runShellCommand:command];
	return @{@"cmd": command, @"output": output};
}
+ (NSDictionary *)commandOutput:(NSArray *)command {
	NSString *output = [self runCommand:command];
	return @{@"cmd": [command componentsJoinedByString:@" "], @"output": output};
}


- (NSString *)expand:(NSString *)string {
	string = [string stringByReplacingOccurrencesOfString:@"$GNUPGHOME" withString:gpgHome];
	string = [string stringByExpandingTildeInPath];
	return string;
}


- (id)plistCompatibleObject:(id)obj {
	// Remove NSNull and convert NSDate to string.
	
	if ([obj isKindOfClass:[NSDictionary class]]) {
		return [self plistDictionary:obj];
	} else if ([obj isKindOfClass:[NSArray class]]) {
		return [self plistArray:obj];
	} else if ([obj isKindOfClass:[NSNull class]]) {
		// NSNull is prohibited is a property list.
		return nil;
	} else if ([obj isKindOfClass:[NSDate class]]) {
		// Convert date to string, because date is illegal in JSON.
		NSISO8601DateFormatter *formatter = [[[NSISO8601DateFormatter alloc] init] autorelease];
		return [formatter stringFromDate:obj];
	} else {
		return obj;
	}
}

- (NSDictionary *)plistDictionary:(NSDictionary *)dictionary {
	NSMutableDictionary *newDictionary = [[NSMutableDictionary new] autorelease];
	
	[dictionary enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
		obj = [self plistCompatibleObject:obj];
		if (obj) {
			newDictionary[key] = obj;
		}
	}];
	
	return newDictionary;
}
- (NSArray *)plistArray:(NSArray *)array {
	NSMutableArray *newArray = [[NSMutableArray new] autorelease];
	
	[array enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		obj = [self plistCompatibleObject:obj];
		if (obj) {
			[newArray addObject:obj];
		}
	}];
	
	return newArray;
}

- (instancetype)init {
	self = [super init];
	if (!self) {
		return nil;
	}
	
	
	debugInfos = [[NSMutableDictionary alloc] init];
	gpgHome = [[[GPGOptions sharedOptions] gpgHome] retain];
	
	return self;
}
- (void)dealloc {
	[debugInfos release];
	[gpgHome release];
	[_pathsToCollect release];
	[super dealloc];
}


@end
