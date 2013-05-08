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
	GPGOptions *options;
}

@property (readonly) NSBundle *myBundle;
@property (readonly) NSArray *secretKeys, *secretKeyDescriptions;
@property (readonly) NSAttributedString *credits;
@property NSInteger indexOfSelectedSecretKey;
@property NSInteger passphraseCacheTime;
@property (retain) NSString *comments;
@property (readonly) GPGOptions *options;
@property (readonly) NSString *bundleVersion, *bundleBuildNumber, *version, *buildNumberDescription, *versionDescription;
@property BOOL autoKeyRetrive;


// Get a list of keyservers from GPGOptions
@property (readonly) NSArray *keyservers;

// To set keyserver and also coordinate auto-key-locate
@property (assign) NSString *keyserver;

/* Open FAQ */
- (IBAction)openKnowledgeBase:(id)pId;

/* Open Contact */
- (IBAction)openContact:(id)pId;

/* Open Donate */
- (IBAction)openDonate:(id)pId;


- (IBAction)deletePassphrases:(id)sender;

// Clear any assigned default-key
- (IBAction)unsetDefaultKey:(id)sender;

/* Remove the selected keyserver from the list */
- (IBAction)removeKeyserver:(id)sender;

@end
