//
//  UpdateButton.h
//  GPGMail
//
//  Created by Alexander Willner on 04.08.10.
//  Copyright 2010 GPGMail Project Team. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface GPGMailPrefController : NSButtonCell {

}

/**
 * Open the GPGMail web site.
 */
- (IBAction)gpgmailOpenURL:(id)pId;

/*
 * Remove GPGMail plug-in.
 */
- (IBAction)gpgmailRemove:(id)pId;

/*
 * Fix GPGMail plug-in.
 */
- (IBAction)gpgmailFix:(id)pId;

@end
