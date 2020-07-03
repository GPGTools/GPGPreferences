#import <Foundation/Foundation.h>

@interface GPGDebugCollector : NSObject <NSStreamDelegate> {
	NSMutableDictionary *debugInfos;
	NSString *gpgHome;
	NSMutableDictionary<NSString *, NSMutableArray *> *_pathsToCollect;
}

- (NSDictionary *)debugInfos;
+ (NSString *)runShellCommand:(NSString *)command;
+ (NSString *)runCommand:(NSArray *)command;

@end
