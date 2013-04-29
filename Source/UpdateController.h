//
//  UpdateController.h
//  GPGPreferences
//
//  Created by Mento on 26.04.2013
//
//

#import <Foundation/Foundation.h>
#import <Sparkle/Sparkle.h>


@interface UpdateController : NSObject {
	SUUpdater *updater;
}

- (NSString *)pathToTool:(NSString *)tool;
- (BOOL)isToolInstalled:(NSString *)tool;

@end
