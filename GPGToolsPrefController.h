//
//  UpdateButton.h
//  GPGTools
//
//  Created by Alexander Willner on 04.08.10.
//  Copyright 2010 GPGTools Project Team. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface GPGToolsPrefController : NSButtonCell {

}

/**
 * Open the GPGTools web site.
 */
- (IBAction)gpgtoolsOpenURL:(id)pId;

/*
 * Remove GPGTools plug-in.
 */
- (IBAction)gpgmailRemove:(id)pId;

/*
 * Fix GPGTools plug-in.
 */
- (IBAction)gpgmailFix:(id)pId;

@end
