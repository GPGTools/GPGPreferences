#import "GPGDebugCollector.h"
#import <Libmacgpg/Libmacgpg.h>
#import <sys/socket.h>
#import <sys/un.h>


@interface NoRealClass
+ (NSString *)GPGPath;
+ (NSString *)pinentryPath;
@end


@implementation GPGDebugCollector


// Returns all debug infos in a dictionary.
- (NSDictionary *)debugInfos {
	[self collectAllDebugInfo];
	return [[debugInfos copy] autorelease];
}



// Calls all the other methods.
- (void)collectAllDebugInfo {
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
		[self collectLogs];
	} @catch (NSException *exception) {}
	@try {
		[self collectKeyListings];
	} @catch (NSException *exception) {}
	@try {
		[self testEncryptAndSign];
	} @catch (NSException *exception) {}
}

// Test encryption and signing.
- (void)testEncryptAndSign {
	NSString *gpgPath = debugInfos[@"Paths"][@"gpg"];
	if (gpgPath == nil) {
		return;
	}
	
	NSMutableDictionary *results = [NSMutableDictionary dictionary];
	
	results[@"Encrypt GPGTools"] = [self runShellCommand:[NSString stringWithFormat:@"'%@' -aer 85E38F69046B44C1EC9FB07B76D78F0500D026C4 <<<test", gpgPath]];
	results[@"Encrypt Self"] = [self runShellCommand:[NSString stringWithFormat:@"'%@' -ae --default-recipient-self <<<test", gpgPath]];
	results[@"Encrypt+Decrypt"] = [self runShellCommand:[NSString stringWithFormat:@"'%@' -ae --default-recipient-self <<<test | '%@' -d", gpgPath, gpgPath]];

	results[@"Sign"] = [self runShellCommand:[NSString stringWithFormat:@"'%@' -as <<<test", gpgPath]];
	results[@"Sign+Encrypt"] = [self runShellCommand:[NSString stringWithFormat:@"'%@' -aser 85E38F69046B44C1EC9FB07B76D78F0500D026C4 --default-recipient-self <<<test", gpgPath]];

	
	debugInfos[@"Encrypt/Sign"] = results;
}

// List of user's keys.
- (void)collectKeyListings {
	NSString *gpgPath = debugInfos[@"Paths"][@"gpg"];
	if (gpgPath == nil) {
		return;
	}
	
	NSMutableDictionary *listings = [NSMutableDictionary dictionary];

	listings[@"Public"] = [self linesFromString:[self runCommand:@[gpgPath, @"-k"]]];
	listings[@"Secret"] = [self linesFromString:[self runCommand:@[gpgPath, @"-K"]]];
	
	debugInfos[@"Key Listings"] = listings;
}

// Logging from Mail.app.
- (void)collectLogs {
	NSMutableDictionary *logs = [NSMutableDictionary dictionary];
	
	logs[@"Mail"] = [self linesFromString:[self runShellCommand:@"egrep ' Mail\\[\\d+\\]: ' < /var/log/system.log"]];
	
	debugInfos[@"Logs"] = logs;
}

// Are Mail bundles enabled?
- (void)collectMailBundleConfig {
	NSMutableDictionary *bundleConfig = [NSMutableDictionary dictionary];

	bundleConfig[@"EnableBundles"] = [self runShellCommand:@"defaults read com.apple.mail EnableBundles"];
	bundleConfig[@"BundleCompatibilityVersion"] = [self runShellCommand:@"defaults read com.apple.mail BundleCompatibilityVersion"];
	
	debugInfos[@"Bundle Config"] = bundleConfig;
}

// Test if the agent is running correctly.
- (void)collectAgentInfos {
	NSMutableDictionary *agentInfos = [NSMutableDictionary dictionary];
	
	agentInfos[@"Normal call"] = [self runShellCommand:@"gpg-agent"];
	agentInfos[@"Direct call"] = [self runCommand:@[@"/usr/local/MacGPG2/bin/gpg-agent"]];
	agentInfos[@"ps"] = [self runShellCommand:@"ps axo command | grep '[g]pg-agent'"];

	debugInfos[@"Agent Infos"] = agentInfos;
}

// Find gpg, gpg2, gpg-agent and pinetry binaries.
- (void)collectBinaryPaths {
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

	paths[@"GnuPGs"] = [self linesFromString:[self runShellCommand:@"which -a gpg gpg2"]];
	paths[@"Agents"] = [self linesFromString:[self runShellCommand:@"which -a gpg-agent"]];
	
	debugInfos[@"Paths"] = paths;
}

// Versions of all binaries found by collectBinaryPaths.
- (void)collectBinaryVersions {
	NSDictionary *allPaths = debugInfos[@"Paths"];
	NSMutableSet *binaries = [NSMutableSet set];
	
	if (allPaths[@"GnuPGs"]) {
		[binaries addObjectsFromArray:allPaths[@"GnuPGs"]];
	}
	if (allPaths[@"Agents"]) {
		[binaries addObjectsFromArray:allPaths[@"Agents"]];
	}
	if (allPaths[@"gpg"]) {
		[binaries addObject:allPaths[@"gpg"]];
	}
	if (allPaths[@"pinentry"]) {
		[binaries addObject:allPaths[@"pinentry"]];
	}
	
	NSMutableDictionary *versions = [NSMutableDictionary dictionary];
	
	for (NSString *binary in binaries) {
		NSString *string = [self runCommand:@[binary, @"--version"]];
		if (string == nil) {
			string = @"";
		}
		versions[binary] = string;
		[self collectInfoForPath:binary maxLinkDepth:2];
	}
	
	debugInfos[@"Versions"] = versions;
}



// All environment variables.
- (void)collectEnvironment {
	debugInfos[@"Environment"] = [[NSProcessInfo processInfo] environment];
	
	NSArray *lines = [self linesFromString:[self runShellCommand:@"printenv"]];
	if (lines) {
		debugInfos[@"Shell Environment"] = lines;
	}
	
	lines = [self linesFromString:[self runCommand:@[@"/sbin/mount"]]];
	if (lines) {
		debugInfos[@"Mount"] = lines;
	}
}



// Content of files and responses from sockets.
- (void)collectFileContents {
	NSArray *files = @[
					   @"$GNUPGHOME/S.gpg-agent",
					   @"$GNUPGHOME/gpg.conf",
					   @"$GNUPGHOME/gpg-agent.conf",
					   @"$GNUPGHOME/scdaemon.conf",
					   @"$GNUPGHOME/dirmngr.conf"
					   ];
	for (NSString *path in files) {
		NSString *expandedPath = [self expand:path];
		[self collectContentOfFile:expandedPath];
	}
}

- (NSString *)contentOfFile:(NSString *)file {
	const char *path = file.UTF8String;
	NSUInteger length = [file lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
	int fd = -1;
	
	fd = open(path, O_RDONLY);
	if (fd < 0) {
		if (errno != EOPNOTSUPP) {
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

- (void)collectContentOfFile:(NSString *)file {
	NSString *content = [self contentOfFile:file];
	
	if (debugInfos[@"File Contents"] == nil) {
		debugInfos[@"File Contents"] = [NSMutableDictionary dictionary];
	}

	debugInfos[@"File Contents"][file] = content;
}



// Attributes of files and folders.
- (void)collectFileInfos {
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSArray *pathsToCheck = @[@"/Applications/GPG Keychain.app",
							  @"/Applications/GPG Keychain Access.app",
							  
							  @"/Library/Services",
							  @"/Library/Services/GPGServices.service",
							  @"~/Library/Services",
							  @"~/Library/Services/GPGServices.service",
							  
							  @"/usr/local",
							  @"/usr/local/MacGPG1",
							  @"/usr/local/MacGPG2",
							  @"/usr/local/MacGPG2/bin/gpg2",
							  @"/usr/local/MacGPG2/libexec/pinentry-mac.app",
							  
							  @"/Library/Mail/Bundles/*",
							  @"~/Library/Mail/Bundles/*",
							  @"/Network/Library/Mail/Bundles/*",
							  
							  @"/Library/PreferencePanes/GPGPreferences.prefPane",
							  @"~/Library/PreferencePanes/GPGPreferences.prefPane",
							  
							  @"/Library/LaunchAgents/org.gpgtools.macgpg2.gpg-agent.plist",
							  @"~/Library/LaunchAgents/org.gpgtools.macgpg2.gpg-agent.plist",
							  
							  @"$GNUPGHOME",
							  @"$GNUPGHOME/*"
							  ];
	
	for (NSString *path in pathsToCheck) {
		NSString *expandedPath = [self expand:path];
		if ([[expandedPath substringWithRange:NSMakeRange(expandedPath.length - 2, 2)] isEqualToString:@"/*"]) {
			NSString *dir = [expandedPath substringWithRange:NSMakeRange(0, expandedPath.length - 2)];
			[self collectInfoForPath:dir maxLinkDepth:2];
			
			for (NSString *filename in [fileManager contentsOfDirectoryAtPath:dir error:nil]) {
				if ([filename isEqualToString:@".DS_Store"]) {
					continue;
				}
				expandedPath = [dir stringByAppendingPathComponent:filename];
				[self collectInfoForPath:expandedPath maxLinkDepth:2];
			}
		} else {
			[self collectInfoForPath:expandedPath maxLinkDepth:2];
		}
	}
}

- (void)collectInfoForPath:(NSString *)path maxLinkDepth:(NSInteger)depth {
	if (debugInfos[@"File Infos"] == nil) {
		debugInfos[@"File Infos"] = [NSMutableDictionary dictionary];
	}
	if (debugInfos[@"File Infos"][path] != nil) {
		// Info for path already collected.
		return;
	}
	
	
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSArray *attributeKeys = @[NSFileGroupOwnerAccountID,
							   NSFileGroupOwnerAccountName,
							   NSFileOwnerAccountID,
							   NSFileOwnerAccountName,
							   NSFilePosixPermissions,
							   NSFileType];

	if ([fileManager fileExistsAtPath:path] == NO) {
		return;
	}
	NSError *error = nil;
	NSDictionary *attributes = [fileManager attributesOfItemAtPath:path error:&error];
	id info = nil;
	if (attributes) {
		info = [attributes dictionaryWithValuesForKeys:attributeKeys];
		
		if ([info[NSFileType] isEqualToString:NSFileTypeSymbolicLink]) {
			NSString *linkDestination = [fileManager destinationOfSymbolicLinkAtPath:path error:nil];
			if (linkDestination) {
				info = [[info mutableCopy] autorelease];
				info[@"LinkDestination"] = linkDestination;
				if (depth > 0) {
					[self collectInfoForPath:linkDestination maxLinkDepth:depth - 1];
				}
			}
		}
		
	} else {
		info = error.description;
		if (!info) {
			info = @"";
		}
	}
	
	
	debugInfos[@"File Infos"][path] = info;
}



- (NSArray *)linesFromString:(NSString *)string {
	NSArray *components = [string componentsSeparatedByString:@"\n"];
	NSArray *lines = [components filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"length > 0"]];
	return lines;
}

- (NSString *)runShellCommand:(NSString *)command {
	if (command == nil) {
		return @"";
	}
	return [self runCommand:[@[@"/bin/bash", @"-l", @"-c"] arrayByAddingObject:command]];
}
- (NSString *)runCommand:(NSArray *)command {
	if (command.count == 0) {
		return @"";
	}
	@try {
		NSTask *task = [[[NSTask alloc] init] autorelease];
		NSPipe *pipe = [NSPipe pipe];
		task.standardOutput = pipe;
		task.standardError = pipe;
		task.launchPath = command[0];
		if (command.count > 1) {
			task.arguments = [command subarrayWithRange:NSMakeRange(1, command.count - 1)];
		}
		[task launch];
		NSString *string = [[[pipe fileHandleForReading] readDataToEndOfFile] gpgString];
		if (string == nil) {
			string = @"";
		}
		string = [string stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
		return string;
	}
	@catch (NSException *exception) {
		return [NSString stringWithFormat:@"Error: %@", exception.description];
	}
}

- (NSString *)expand:(NSString *)string {
	string = [string stringByReplacingOccurrencesOfString:@"$GNUPGHOME" withString:gpgHome];
	string = [string stringByExpandingTildeInPath];
	return string;
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
	[super dealloc];
}


@end
