//
//  MIExceptionTracker.m
//  MappIntelligenceSDK
//
//  Created by Stefan Stevanovic on 27/08/2021.
//  Copyright © 2021 Mapp Digital US, LLC. All rights reserved.
//

#import "MIExceptionTracker.h"
#import "MappIntelligenceLogger.h"
#import "MIActionEvent.h"
#import "MIDefaultTracker.h"

typedef void SignalHanlder(NSException *exception);

@interface MIExceptionTracker ()
@property SignalHanlder* previousSignalHandlers;
@property (nonatomic, strong) MIDefaultTracker* tracker;
#if !TARGET_OS_WATCH
@property NSArray<id>* signals;
#endif
@property (nonatomic, strong) MappIntelligenceLogger* logger;
@end

@implementation MIExceptionTracker
@synthesize initialized = _initialized;

+ (nullable instancetype)sharedInstance {

  static MIExceptionTracker *shared = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    shared = [[MIExceptionTracker alloc] init];
  });
  return shared;
}

-(id)init {
     if (self = [super init])  {
#if !TARGET_OS_WATCH
         _signals = @[@SIGABRT, @SIGILL, @SIGSEGV, @SIGFPE, @SIGBUS, @SIGPIPE, @SIGTRAP];
#endif
         _logger = [MappIntelligenceLogger shared];
         _tracker = [MIDefaultTracker sharedInstance];
       self.initialized = NO;
     }
     return self;
}

- (instancetype)initializeExceptionTracking {
    if (self.initialized) {
        return self;
    }
    
    [self installUncaughtExceptionHandler];
    self.initialized = YES;
    return self;
}

- (void) installUncaughtExceptionHandler {
    _previousSignalHandlers = NSGetUncaughtExceptionHandler();
    [_logger logObj:@"exception tracking has been initialized" forDescription:kMappIntelligenceLogLevelDescriptionInfo];
}

-(BOOL) checkIfInitialized {
    if (!self.initialized) {
        [_logger logObj:@"MappIntelligence exception tracking isn't initialited" forDescription:kMappIntelligenceLogLevelDescriptionInfo];
    }
    return self.initialized;
}

- (NSError*) trackInfoWithName:(NSString *)name andWithMessage:(NSString *)message {
    if (![self checkIfInitialized]) {
        return [NSError errorWithDomain:@"com.mapp.mappIntelligence" code:900 userInfo:@{@"Error reason": @"MappIntelligence exception tracking isn't initialited"}];
    }
    ///satisfyToLevel
    
    return [self trackWithType:NULL withName:name withMessage:message withStack:NULL withStackReturnAddress:NULL withUserInfo:NULL];
    
}

- (NSError*)trackException:(NSException *)exception {
    if (![self checkIfInitialized]) {
        return [NSError errorWithDomain:@"com.mapp.mappIntelligence" code:900 userInfo:@{@"Error reason": @"MappIntelligence exception tracking isn't initialited"}];
    }
    ///satisfy to level
    
    return [self trackWithType:NULL withName:exception.name withMessage:exception.reason withStack:[[exception.callStackSymbols valueForKey:@"description"] componentsJoinedByString:@""] withStackReturnAddress:[[exception.callStackReturnAddresses valueForKey:@"description"] componentsJoinedByString:@""] withUserInfo:[NSString stringWithFormat:@"%@", exception.userInfo]];
}

- (NSError*)trackError:(NSError *)error {
    if (![self checkIfInitialized]) {
        return [NSError errorWithDomain:@"com.mapp.mappIntelligence" code:900 userInfo:@{@"Error reason": @"MappIntelligence exception tracking isn't initialited"}];
    }
    ///satisfyToLevel
    
    return [self trackWithType:NULL withName:@"Error" withMessage:error.localizedDescription withStack:NULL withStackReturnAddress:NULL withUserInfo:NULL];
}

- (NSError*)trackWithType: (NSString * _Nullable) type withName:(NSString* _Nullable) name withMessage: (NSString* _Nullable) message withStack: (NSString* _Nullable)stack withStackReturnAddress: (NSString* _Nullable) stackReturnAddress withUserInfo: (NSString* _Nullable) userInfo {
    
    //define details
    MIActionEvent* actionEvent = [[MIActionEvent alloc] initWithName:@"webtrekk_ignore"];
    NSMutableDictionary* parameters = [[NSMutableDictionary alloc] init];
    if (type) {
        [parameters setObject:type forKey:[NSNumber numberWithInt:910]];
    }
    if (name) {
        [parameters setObject:name forKey:[NSNumber numberWithInt:911]];
    }
    if (message) {
        [parameters setObject:message forKey:[NSNumber numberWithInt:912]];
    }
    if (stack) {
        [parameters setObject:stack forKey:[NSNumber numberWithInt:913]];
    }
    if (userInfo) {
        [parameters setObject:userInfo forKey:[NSNumber numberWithInt:916]];
    }
    if (stackReturnAddress) {
        [parameters setObject:stackReturnAddress forKey:[NSNumber numberWithInt:917]];
    }
    
    MIEventParameters* actionProperties = [[MIEventParameters alloc] initWithParameters:parameters];
    actionEvent.eventParameters = actionProperties;
    
    return [_tracker trackWithCustomEvent:actionEvent];
}

@end
