//
//  GPGPVersionInfo.h
//  GPGPreferences
//
//  Created by Mento on 19.06.20.
//  Copyright © 2020 GPGTools. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GMSupportPlanManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface GPGPVersionInfo : NSObject

+ (instancetype)sharedInstance;

- (NSArray *)toolVersions;
- (NSString *)versionInfo;
- (NSString *)humanReadableSupportPlanStatus;
- (NSAttributedString *)attributedVersions;
- (NSString *)gpgMailLoadingStateWithToolVersion:(NSDictionary *)toolVersion;
- (GMSupportPlanManager *)supportPlanManager;
- (NSBundle *)GPGMailBundleForVersion:(NSString *)version;

@end

NS_ASSUME_NONNULL_END
