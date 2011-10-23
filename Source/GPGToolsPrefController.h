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
@property (readonly) NSArray *secretKeys, *keyservers;
@property (readonly) NSAttributedString *credits;
@property (readonly) NSString *bundleVersion;
@property NSUInteger indexOfSelectedSecretKey;

/* Remove GPGMail plug-in. */
- (IBAction)gpgmailRemove:(id)pId;

/* Fix GPGTools. */
- (IBAction)gpgFix:(id)pId;

/* Open FAQ */
- (IBAction)openFAQ:(id)pId;

/* Open Contact */
- (IBAction)openContact:(id)pId;

/* Open Donate */
- (IBAction)openDonate:(id)pId;


@end
