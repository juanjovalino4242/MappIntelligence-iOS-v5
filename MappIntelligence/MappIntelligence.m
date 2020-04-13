//
//  Webrekk.m
//  Webrekk
//
//  Created by Stefan Stevanovic on 1/3/20.
//  Copyright © 2020 Stefan Stevanovic. All rights reserved.
//

#import "MappIntelligence.h"
#import "MappIntelligenceDefaultConfig.h"
#import "MappIntelligenceLogger.h"

@interface MappIntelligence ()

@property MappIntelligenceDefaultConfig *configuration;
@property DefaultTracker *tracker;
@property MappIntelligenceLogger *logger;

@end

@implementation MappIntelligence

static MappIntelligence *sharedInstance = nil;
static MappIntelligenceDefaultConfig *config = nil;

@synthesize tracker;

- (id)init {
  if (!sharedInstance) {
    sharedInstance = [super init];
    config = [[MappIntelligenceDefaultConfig alloc] init];
    _logger = [MappIntelligenceLogger shared];
  }
  return sharedInstance;
}

+ (nullable instancetype)shared {
  static MappIntelligence *shared = nil;

  static dispatch_once_t onceToken;

  dispatch_once(&onceToken, ^{

    shared = [[MappIntelligence alloc] init];
  });

  return shared;
}

+ (NSString *)version {
  return @"5.0.0";
}

+ (NSString *)getUrl {
  return ([config trackDomain] == NULL) ? @"" : [config trackDomain];;
}

+ (NSString *)getId {
  return ([[config trackIDs] firstObject] == NULL)
             ? @""
             : [NSString
                   stringWithFormat:@"%@", [[config trackIDs] componentsJoinedByString:@","]];
}

#if !TARGET_OS_WATCH
- (NSError *_Nullable)trackPage:(UIViewController *)controller {
  return [tracker track:controller];
}
#endif

- (NSError *_Nullable)trackPageWith:(NSString *)name {
  return [tracker trackWith:name];
}

- (void)initWithConfiguration:(NSArray *)trackIDs
                        onTrackdomain:(NSString *)trackDomain
              withAutotrackingEnabled:(BOOL)autoTracking
                       requestTimeout:(NSTimeInterval)requestTimeout
                     numberOfRequests:(NSInteger)numberOfRequestInQueue
                  batchSupportEnabled:(BOOL)batchSupport
    viewControllerAutoTrackingEnabled:(BOOL)viewControllerAutoTracking
                          andLogLevel:(logLevel)lv {

  [config setLogLevel:(MappIntelligenceLogLevelDescription)lv];
  [config setTrackIDs:trackIDs];
  [config setTrackDomain:trackDomain];
  [config setAutoTracking:autoTracking];
  [config setBatchSupport:batchSupport];
  [config setViewControllerAutoTracking:viewControllerAutoTracking];
  [config setRequestPerQueue:numberOfRequestInQueue];
  [config setRequestsInterval:requestTimeout];
  [config logConfig];

  tracker = [DefaultTracker sharedInstance];
  [tracker initializeTracking];
}

- (void)initWithConfiguration:(NSArray *)trackIDs onTrackdomain:(NSString *)trackDomain requestTimeout:(NSTimeInterval)requestTimeout andLogLevel:(logLevel)lv {
    [self initWithConfiguration:trackIDs onTrackdomain:trackDomain withAutotrackingEnabled:YES requestTimeout:requestTimeout numberOfRequests:10 batchSupportEnabled:YES viewControllerAutoTrackingEnabled:YES andLogLevel:lv];
}

- (void)reset {
    sharedInstance = NULL;
    sharedInstance = [self init];
    [_logger logObj:@"Reset Mapp Inteligence Instance."
        forDescription:kMappIntelligenceLogLevelDescriptionDebug];
    [config logConfig];
    [tracker reset];
}

@end
