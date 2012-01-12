//
//  UpdateButton.h
//  GPGTools
//
//  Created by Alexander Willner on 04.08.10.
//  Edited by Roman Zechmeister 11.07.2011
//  Copyright 2010 GPGTools Project Team. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Libmacgpg/Libmacgpg.h>


@interface GPGToolsPrefController : NSObject <GPGControllerDelegate> {
	NSBundle *myBundle;
	NSArray *secretKeys;
	GPGController *gpgc;
	NSLock *secretKeysLock;
}

@property (readonly) NSBundle *myBundle;
@property (readonly) NSArray *secretKeys, *secretKeyDescriptions;
@property (readonly) NSAttributedString *credits;
@property (readonly) NSString *bundleVersion;
@property NSUInteger indexOfSelectedSecretKey;
@property NSInteger passphraseCacheTime;

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


- (IBAction)deletePassphrases:(id)sender;


@end
