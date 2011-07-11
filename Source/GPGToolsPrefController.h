//
//  UpdateButton.h
//  GPGTools
//
//  Created by Alexander Willner on 04.08.10.
//  Edited by Roman Zechmeister 11.07.2011
//  Copyright 2010 GPGTools Project Team. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface GPGToolsPrefController : NSObject {
	NSBundle *myBundle;
	NSArray *secretKeys;
}
@property (readonly) NSBundle *myBundle;
@property (readonly) NSArray *secretKeys;
@property NSUInteger indexOfSelectedSecretKey;

/*
 * Remove GPGMail plug-in.
 */
- (IBAction)gpgmailRemove:(id)pId;

/*
 * Fix GPGMail plug-in.
 */
- (IBAction)gpgmailFix:(id)pId;

/*
 * Fix GPG.
 */
- (IBAction)gpgFix:(id)pId;


- (NSAttributedString *)credits;

@end
