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

@class SUUpdater;

@interface GPGToolsPrefController : NSObject <GPGControllerDelegate> {
	NSBundle *myBundle;
	NSArray *secretKeys;
	GPGController *gpgc;
	NSLock *secretKeysLock;
	SUUpdater *updater;
	GPGOptions *options;
}

@property (readonly, retain) SUUpdater *updater;
@property (readonly) NSBundle *myBundle;
@property (readonly) NSArray *secretKeys, *secretKeyDescriptions;
@property (readonly) NSAttributedString *credits;
@property (readonly) NSString *bundleVersion;
@property NSInteger indexOfSelectedSecretKey;
@property NSInteger passphraseCacheTime;
@property (retain) NSString *comments;
@property (readonly) GPGOptions *options;

// Get a list of keyservers from GPGOptions
@property (readonly) NSArray *keyservers;

// To set keyserver and also coordinate auto-key-locate
@property (assign) NSString *keyserver;

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

// Clear any assigned default-key
- (IBAction)unsetDefaultKey:(id)sender;

@end
