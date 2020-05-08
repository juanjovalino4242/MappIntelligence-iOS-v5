//
//  DefaultTracker.m
//  MappIntelligenceSDK
//
//  Created by Vladan Randjelovic on 11/02/2020.
//  Copyright © 2020 Mapp Digital US, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#if TARGET_OS_WATCH
#import <WatchKit/WatchKit.h>
#endif

#import "DefaultTracker.h"
#import "MappIntelligenceLogger.h"
#import "MappIntelligence.h"
#import "Properties.h"
#import "Enviroment.h"
#import "Configuration.h"
#import "RequestTrackerBuilder.h"
#import "TrackerRequest.h"
#import "RequestUrlBuilder.h"
#import "UIFlowObserver.h"

#define appHibernationDate @"appHibernationDate"
#define appVersion @"appVersion"
#define configuration @"configuration"
#define everId @"everId"
#define isFirstEventOfApp @"isFirstEventOfApp"

@interface DefaultTracker ()

@property Configuration *config;
@property MappIntelligenceLogger *logger;
@property TrackingEvent *event;
@property RequestUrlBuilder *requestUrlBuilder;
@property NSUserDefaults* defaults;
@property BOOL isFirstEventOpen;
@property BOOL isFirstEventOfSession;
@property UIFlowObserver *flowObserver;
@property NSCondition *conditionUntilGetFNS;

- (void)enqueueRequestForEvent:(TrackingEvent *)event;
- (Properties *)generateRequestProperties;

@end

@implementation DefaultTracker : NSObject

static DefaultTracker *sharedTracker = nil;
static NSString *everID;
static NSString *userAgent;

+ (nullable instancetype)sharedInstance {

  static DefaultTracker *shared = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    shared = [[DefaultTracker alloc] init];
  });
  return shared;
}

- (instancetype)init {
  if (!sharedTracker) {
    sharedTracker = [super init];
    everID = [sharedTracker generateEverId];
    _config = [[Configuration alloc] init];
    _logger = [MappIntelligenceLogger shared];
    _defaults = [NSUserDefaults standardUserDefaults];
    _flowObserver = [[UIFlowObserver alloc] initWith:self];
    [_flowObserver setup];
    _conditionUntilGetFNS = [[NSCondition alloc] init];
    _isReady = NO;
    [self generateUserAgent];
    [self initializeTracking];
  }
  return sharedTracker;
}

- (void)generateUserAgent {
  Enviroment *env = [[Enviroment alloc] init];
  NSString *properties = [env.operatingSystemName
      stringByAppendingFormat:@" %@; %@; %@", env.operatingSystemVersionString,
                              env.deviceModelString,
                              NSLocale.currentLocale.localeIdentifier];

  userAgent =
      [[NSString alloc] initWithFormat:@"Tracking Library %@ (%@))",
                                       MappIntelligence.version, properties];
}

- (void)initializeTracking {
  _config.serverUrl = [[NSURL alloc] initWithString:[MappIntelligence getUrl]];
  _config.MappIntelligenceId = [MappIntelligence getId];
  _requestUrlBuilder =
      [[RequestUrlBuilder alloc] initWithUrl:_config.serverUrl
                                   andWithId:_config.MappIntelligenceId];
}

- (NSString *)generateEverId {

  NSString *tmpEverId = [[DefaultTracker sharedDefaults] stringForKey:everId];
  // https://nshipster.com/nil/ read for more explanation
  if (tmpEverId != nil) {
    return tmpEverId;
  } else {
    return [self getNewEverID];
  }

  return @"";
}

- (NSString *)getNewEverID {
  NSString *tmpEverId = [[NSString alloc]
      initWithFormat:@"6%010.0f%08u",
                     [[[NSDate alloc] init] timeIntervalSince1970],
                     arc4random_uniform(99999999) + 1];
  [[DefaultTracker sharedDefaults] setValue:tmpEverId forKey:everId];

  if ([everId isEqual:[[NSNull alloc] init]]) {
    @throw @"Can't generate ever id";
  }
  return tmpEverId;
}
#if !TARGET_OS_WATCH
- (NSError *_Nullable)track:(UIViewController *)controller {
  NSString *CurrentSelectedCViewController =
      NSStringFromClass([controller class]);
  return [self trackWith:CurrentSelectedCViewController];
}
#endif
- (NSError *_Nullable)trackWith:(NSString *)name {
  if ([_config.MappIntelligenceId isEqual:@""] ||
      [_config.serverUrl.absoluteString isEqual:@""]) {
    NSString *msg =
        @"Request can not be sent with empty track domain or track id.";
    [_logger logObj:msg
        forDescription:kMappIntelligenceLogLevelDescriptionDebug];
    NSString *domain = @"com.mapp.mappIntelligenceSDK.ErrorDomain";
    NSString *desc = NSLocalizedString(msg, @"");
    NSDictionary *userInfo = @{NSLocalizedDescriptionKey : desc};
    NSError *error =
        [NSError errorWithDomain:domain code:-101 userInfo:userInfo];
    return error;
  }
  if ([name length] > 255) {
    [_logger logObj:@"Content ID contains more than 255 characters, and that "
                    @"part will be cutted automatically."
        forDescription:kMappIntelligenceLogLevelDescriptionWarning];
  }
  if (![_defaults stringForKey:isFirstEventOfApp]) {
    [_defaults setBool:YES forKey:isFirstEventOfApp];
    [_defaults synchronize];
    _isFirstEventOpen = YES;
    _isFirstEventOfSession = YES;
  } else {
    _isFirstEventOpen = NO;
  }

  [_logger logObj:[[NSString alloc] initWithFormat:@"Content ID is: %@", name]
      forDescription:kMappIntelligenceLogLevelDescriptionDebug];

  // create request with page event
  TrackingEvent *event = [[TrackingEvent alloc] init];
  [event setPageName:name];
#ifdef TARGET_OS_WATCH
    _isReady = YES;
#endif

  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
                 ^(void) {
                   // Background Thread
                   [self->_conditionUntilGetFNS lock];
                   while (!self->_isReady)
                     [self->_conditionUntilGetFNS wait];
                   dispatch_async(dispatch_get_main_queue(), ^(void) {
                     // Run UI Updates
                     [self enqueueRequestForEvent:event];
                     [self->_conditionUntilGetFNS unlock];
                   });
                 });
    return NULL;
}

- (void)enqueueRequestForEvent:(TrackingEvent *)event {
  Properties *requestProperties = [self generateRequestProperties];
  requestProperties.locale = [NSLocale currentLocale];

  [requestProperties setIsFirstEventOfApp:_isFirstEventOpen];
  [requestProperties setIsFirstEventOfSession:_isFirstEventOfSession];
  [requestProperties setIsFirstEventAfterAppUpdate:NO];

  RequestTrackerBuilder *builder =
      [[RequestTrackerBuilder alloc] initWithConfoguration:self.config];

  TrackerRequest *request =
      [builder createRequestWith:event andWith:requestProperties];

  NSURL *requestUrl = [_requestUrlBuilder urlForRequest:request];

  [request sendRequestWith:requestUrl
           andCompletition:^(NSError *_Nonnull error) {
             if (error) {
               [self->_logger
                           logObj:[[NSString alloc]
                                      initWithFormat:
                                          @"Request: %@ ended with error: %@",
                                          requestUrl, error]
                   forDescription:kMappIntelligenceLogLevelDescriptionError];
             }
           }];
  _isFirstEventOfSession = NO;
  _isFirstEventOpen = NO;
}

- (Properties *)generateRequestProperties {
  return [[Properties alloc] initWithEverID:everID
                            andSamplingRate:0
                               withTimeZone:[NSTimeZone localTimeZone]
                              withTimestamp:[NSDate date]
                              withUserAgent:userAgent];
}

+ (NSUserDefaults *)sharedDefaults {
  return [NSUserDefaults standardUserDefaults];
}

- (void)initHibernate {
  NSDate *date = [[NSDate alloc] init];
  [_logger logObj:[[NSString alloc] initWithFormat:@"save current date for "
                                                   @"session detection %@ "
                                                   @"with defaults %d",
                                                   date, _defaults == NULL]
      forDescription:kMappIntelligenceLogLevelDescriptionDebug];
  [_defaults setObject:date forKey:appHibernationDate];
  _isReady = NO;
}
#if !TARGET_OS_WATCH
- (void)updateFirstSessionWith:(UIApplicationState)state {
  if (state == UIApplicationStateInactive) {
    _isFirstEventOfSession = YES;
  } else {
    _isFirstEventOfSession = NO;
  }
  [self fireSignal];
    
}
#else
- (void)updateFirstSessionWith:(WKApplicationState)state {
  NSDate *date = [[NSDate alloc] init];
  [_logger logObj:[[NSString alloc]
                      initWithFormat:
                          @" interval since last close of app:  %f",
                          [date
                              timeIntervalSinceDate:
                                  [_defaults objectForKey:appHibernationDate]]]
      forDescription:kMappIntelligenceLogLevelDescriptionDebug];
  if ([date timeIntervalSinceDate:[_defaults objectForKey:appHibernationDate]] >
      30 * 60) {
    _isFirstEventOfSession = YES;
  } else {
    _isFirstEventOfSession = NO;
  }
  [self fireSignal];
}
#endif

- (void)fireSignal {
  _isReady = YES;
  [_conditionUntilGetFNS signal];
  [_conditionUntilGetFNS unlock];
}

- (void)reset {
  sharedTracker = NULL;
  sharedTracker = [self init];
  _isReady = YES;
  [_defaults removeObjectForKey:isFirstEventOfApp];
  [_defaults synchronize];
  everID = [self getNewEverID];
}

@end

