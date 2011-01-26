//
//  UpdateButton.m
//  GPGTools
//
//  Created by Alexander Willner on 04.08.10.
//  Copyright 2010 GPGTools Project Team. All rights reserved.
//

#import "GPGToolsPrefController.h"

@implementation GPGToolsPrefController

/**
 * Open the GPGTools web site.
 */
- (IBAction)gpgtoolsOpenURL:(id)pId;
{	
	NSURL *url=[NSURL URLWithString:@"http://gpgtools.org"];
	NSLog(@"Opening '%@'...", url);
	[[NSWorkspace sharedWorkspace] openURL:url];
}


/*
 * Remove GPGMail plug-in.
 *
 * @todo	Is there a method that returns the bundle path?
 * @todo	Use a modal dialog here.
 */
- (IBAction)gpgmailRemove:(id)sender;
{
	NSFileManager *filemgr = [NSFileManager defaultManager];
	NSString *path;

	path = [@"~/Library/Mail/Bundles/GPGMail.mailbundle" stringByExpandingTildeInPath];	
	NSLog(@"Removing '%@'...", path);
	[filemgr removeItemAtPath: path error:NULL];
	
	path = [@"~/Library/Preferences/org.gpgmail.plist" stringByExpandingTildeInPath];	
	NSLog(@"Removing '%@'...", path);
	[filemgr removeItemAtPath: path error:NULL];
	
	NSRunInformationalAlertPanel(@"GPGMail removed:", 
								 @"GPGMail removed.",
								 @"OK", nil, nil);
}


/*
 * Fix GPGMail plug-in.
 *
 * @todo	Doesn't work if installed as system wide preference pane
 * @todo	Do not use shell script, implement it using objective-c instead
 * @todo	Use a modal dialog here.
 */
- (IBAction)gpgmailFix:(id)pId;
{
	NSString *path = [@"~/Library/PreferencePanes/GPGTools.prefPane/Contents/Resources/fix_gpgmail.sh" stringByExpandingTildeInPath];	
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

	NSRunInformationalAlertPanel(@"GPGTools fix result:", 
								 result,
								 @"OK", nil, nil);
	
}

/*
 * Fix GPG.
 *
 * @todo	Doesn't work if installed as system wide preference pane
 * @todo	Do not use shell script, implement it using objective-c instead
 * @todo	Use a modal dialog here.
 */
- (IBAction)gpgFix:(id)pId;
{
	NSString *path = [@"~/Library/PreferencePanes/GPGTools.prefPane/Contents/Resources/fix_gpg.sh" stringByExpandingTildeInPath];	
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
	
	NSRunInformationalAlertPanel(@"GPG fix result:", 
								 result,
								 @"OK", nil, nil);
	
}


@end
