//
//  UpdateButton.m
//  GPGTools
//
//  Created by Alexander Willner on 04.08.10.
//  Edited by Roman Zechmeister 11.07.2011
//  Copyright 2010 GPGTools Project Team. All rights reserved.
//

#import "GPGToolsPrefController.h"
#import <Libmacgpg/Libmacgpg.h>

@implementation GPGToolsPrefController



/*
 * Returns all secret keys.
 *
 * @todo	Support for gpgController:keysDidChangedExernal:
 */
- (NSArray *)secretKeys {
	if (!secretKeys) {
		secretKeys = [[[GPGController gpgController] allSecretKeys] allObjects];
	}
	return secretKeys;
}


/*
 * Displays a simple sheet.
 */
- (void)simpleSheetWithTitle:(NSString *)title informativeText:(NSString *)informativeText {
	NSAlert *alert = [NSAlert alertWithMessageText:title defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:@"%@", informativeText];
	[alert setIcon:[[NSImage alloc] initWithContentsOfURL:[self.myBundle URLForImageResource:@"GPGTools"]]];
	[alert beginSheetModalForWindow:[NSApp mainWindow] modalDelegate:nil didEndSelector:nil contextInfo:nil];	
}

/*
 * The NSBundle for GPGTools.prefPane.
 */
- (NSBundle *)myBundle {
	if (!myBundle) {
		myBundle = [NSBundle bundleForClass:[self class]];
	}
	return myBundle;
}



/*
 * Remove GPGMail plug-in.
 *
 * @todo	Is there a method that returns the bundle path?
 */
- (IBAction)gpgmailRemove:(id)sender {
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSString *path;
	
	
	path = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Mail/Bundles/GPGMail.mailbundle"];	
	NSLog(@"Removing '%@'...", path);
	[fileManager removeItemAtPath: path error:NULL];
	
	path = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Preferences/org.gpgmail.plist"];	
	NSLog(@"Removing '%@'...", path);
	[fileManager removeItemAtPath: path error:NULL];
	
	[self simpleSheetWithTitle:@"GPGMail removed" informativeText:@"GPGMail removed."];
}


/*
 * Fix GPGMail plug-in.
 *
 * @todo	Do not use shell script, implement it using objective-c instead
 */
- (IBAction)gpgmailFix:(id)sender {
	NSString *path = [self.myBundle pathForResource:@"fix_gpgmail" ofType:@"sh"];	
	NSLog(@"Starting '%@'...", path);
	NSTask *task=[[NSTask alloc] init];
	NSPipe *pipe = [NSPipe pipe];
	NSFileHandle *file = [pipe fileHandleForReading];
	[task setStandardOutput:pipe];
	[task setLaunchPath:path];
	[task launch];
	[task waitUntilExit];
	NSData *data = [file readDataToEndOfFile];
	NSString *result = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];

	[self simpleSheetWithTitle:@"GPGTools fix result:" informativeText:result];
}

/*
 * Fix GPG.
 *
 * @todo	Do not use shell script, implement it using objective-c instead
 */
- (IBAction)gpgFix:(id)sender {
	NSString *path = [self.myBundle pathForResource:@"fix_gpg" ofType:@"sh"];
	NSLog(@"Starting '%@'...", path);
	NSTask *task=[[NSTask alloc] init];
	NSPipe *pipe = [NSPipe pipe];
	NSFileHandle *file = [pipe fileHandleForReading];
	[task setStandardOutput:pipe];
	[task setLaunchPath:path];
	[task launch];
	[task waitUntilExit];
	NSData *data = [file readDataToEndOfFile];
	NSString *result = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
	
	[self simpleSheetWithTitle:@"GPG fix result:" informativeText:result];
}


/*
 * Give the credits from Credits.rtf.
 */
- (NSAttributedString *)credits {
	return [[[NSAttributedString alloc] initWithURL:[self.myBundle URLForResource:@"Credits" withExtension:@"rtf"] documentAttributes:nil] autorelease];
}

/*
 * Array of readable descriptions of the secret keys.
 */
- (NSArray *)secretKeyDescriptions {
	NSArray *keys = self.secretKeys;
	NSMutableArray *decriptions = [NSMutableArray arrayWithCapacity:[keys count]];
	for (GPGKey *key in keys) {
		[decriptions addObject:[NSString stringWithFormat:@"%@ – %@", key.userID, key.shortKeyID]];
	}
	return decriptions;
}

/*
 * Index of the default key.
 */
- (NSUInteger)indexOfSelectedSecretKey {
	GPGOptions *options = [GPGOptions sharedOptions];
	NSString *defaultKey = [options valueForKey:@"default-key"];
	
	NSArray *keys = self.secretKeys;
	
	NSUInteger i, count = [keys count];
	for (i = 0; i < count; i++) {
		GPGKey *key = [keys objectAtIndex:i];
		if ([key.textForFilter rangeOfString:defaultKey options:NSCaseInsensitiveSearch].length > 0) {
			return i;
		}		
	}
	
	return 0;
}
- (void)setIndexOfSelectedSecretKey:(NSUInteger)index {
	NSArray *keys = self.secretKeys;
	if (index < [keys count]) {
		GPGOptions *options = [GPGOptions sharedOptions];
		[options setValue:[[keys objectAtIndex:index] fingerprint] forKey:@"default-key"];
	}
}

@end
