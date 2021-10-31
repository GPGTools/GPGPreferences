//
//  GPGToolsPrefController.h
//  GPGTools
//
//  Created by Alexander Willner on 04.08.10.
//  Edited by Roman Zechmeister 11.07.2011
//  Copyright 2016 GPGTools Project Team. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Libmacgpg/Libmacgpg.h>
#import "GPGToolsPref.h"

@class GPGToolsPref;
extern GPGToolsPref *gpgPrefPane;

@interface GPGToolsPrefController : NSObject <GPGControllerDelegate> {
	IBOutlet NSProgressIndicator *spinner;
	NSBundle *myBundle;
	NSArray *secretKeys;
	NSLock *secretKeysLock;
	GPGOptions *options;
	GPGOptions *updaterOptions;
	IBOutlet GPGToolsPref *prefPane;
	NSInteger allowUserEmailContact;
	NSString *crashReportsUserEmail;
	BOOL changingUserEmailEnabled;
}

@property (readonly) NSBundle *myBundle;
@property (readonly) NSArray *secretKeys, *secretKeyDescriptions;
@property (readonly) NSAttributedString *credits;
@property NSInteger indexOfSelectedSecretKey;
@property NSInteger passphraseCacheTime;
@property BOOL rememberPassword;
@property (readonly) GPGOptions *options, *updaterOptions;
@property (readonly) NSString *bundleVersion, *version, *buildNumberDescription, *versionDescription;
@property BOOL automaticallySendCrashReports;
@property (strong) NSString *crashReportsUserEmail;
@property BOOL allowUserEmailContact;
@property (nonatomic) BOOL useKeychain;


// Get a list of keyservers from GPGOptions
@property (readonly) NSArray *keyservers;

// To set keyserver and also coordinate auto-key-locate
@property (assign) NSString *keyserver;

// Test the keyserver, and set it as default.
- (IBAction)testKeyserver:(id)sender;

/* Open FAQ */
- (IBAction)openKnowledgeBase:(id)pId;

/* Open Contact */
- (IBAction)openSupport:(id)pId;


- (IBAction)deletePassphrases:(id)sender;

- (void)mainVieWDidLoad;

@end
