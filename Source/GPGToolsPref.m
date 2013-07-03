//
//  GPGToolsPref.m
//  GPGTools
//
//  Created by Alexander Willner on 04.08.10.
//  Copyright (c) 2010 GPGTools Project Team. All rights reserved.
//

#import "GPGToolsPref.h"
#import <Libmacgpg/Libmacgpg.h>

@implementation GPGToolsPref

- (NSString *)mainNibName {
	if (![GPGController class]) {
		return @"WarningView";
	}
	return [super mainNibName];
}

- (void) mainViewDidLoad {
}

@end
