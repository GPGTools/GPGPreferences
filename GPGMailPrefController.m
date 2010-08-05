//
//  UpdateButton.m
//  GPGMail
//
//  Created by Alexander Willner on 04.08.10.
//  Copyright 2010 GPGMail Project Team. All rights reserved.
//

#import "GPGMailPrefController.h"

@implementation GPGMailPrefController

/**
 * Open the GPGMail web site.
 */
- (IBAction)gpgmailOpenURL:(id)pId;
{	
	NSURL *url=[NSURL URLWithString:@"http://www.gpgmail.org"];
	NSLog(@"Opening %@...", url);
	[[NSWorkspace sharedWorkspace] openURL:url];
}


/*
 * Remove GPGMail plug-in.
 *
 * @todo	Is there a method that returns the bundle path?
 */
- (IBAction)gpgmailRemove:(id)pId;
{
	NSString *path = [@"~/Library/Mail/Bundles/GPGMail.mailbundle" stringByExpandingTildeInPath];	
	NSLog(@"Removing %@...", path);
	NSFileManager *filemgr = [NSFileManager defaultManager];
	[filemgr removeItemAtPath: path error:NULL];
}


/*
 * Fix GPGMail plug-in.
 *
 * @todo	Doesn't work if installed as system wide preference pane
 * @todo	Do not use shell script, implement it using objective-c instead
 */
- (IBAction)gpgmailFix:(id)pId;
{
	NSString *path = [@"~/Library/PreferencePanes/GPGMail.prefPane/Contents/Resources/org.gpgmail.loginscript.sh" stringByExpandingTildeInPath];	
	NSLog(@"Starting %@...", path);
	NSTask *task=[[NSTask alloc] init];
	[task setLaunchPath:path];
	[task launch];
}


@end
