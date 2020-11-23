//
//  MIRequestBatchSupportUrlBuilder.m
//  MappIntelligenceSDK
//
//  Created by Stefan Stevanovic on 02/07/2020.
//  Copyright © 2020 Mapp Digital US, LLC. All rights reserved.
//

#import "MIRequestBatchSupportUrlBuilder.h"
#import "MappIntelligence.h"
#import "MIDefaultTracker.h"
#import "MIDatabaseManager.h"
#import "MIRequestData.h"
#import "MITrackerRequest.h"
#import "MappIntelligenceLogger.h"

@interface MIRequestBatchSupportUrlBuilder ()

@property MIDatabaseManager* dbManager;
@property MappIntelligenceLogger* loger;

@end

@implementation MIRequestBatchSupportUrlBuilder


- (instancetype)init
{
    self = [super init];
    if (self) {
        //initialisation of base url
        MIDefaultTracker* tracker = [MIDefaultTracker sharedInstance];
        _baseUrl = [[NSString alloc] initWithFormat:@"%@/%@/batch?eid=%@&X-WT-UA=%@", [MappIntelligence getUrl], [MappIntelligence getId],  [tracker generateEverId], [[tracker generateUserAgent] stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]] ];
        _dbManager = [MIDatabaseManager shared];
        _loger = [MappIntelligenceLogger shared];
        
    }
    return self;
}

-(void)sendBatchForRequestsWithCompletition:(void (^)(NSError *error))handler {
    [_dbManager fetchAllRequestsFromInterval:[[MappIntelligence shared] batchSupportSize] andWithCompletionHandler:^(NSError * _Nonnull error, id  _Nullable data) {
        if (error) {
            handler(error);
        }
        MIRequestData* dt = (MIRequestData*)data;
        NSArray<NSString *>* bodies = [self createBatchWith:dt];
        MITrackerRequest *request = [[MITrackerRequest alloc] init];
        for (NSString *body in bodies) {
          [request
              sendRequestWith:[[NSURL alloc] initWithString:self->_baseUrl]
                      andBody:body
              andCompletition:^(NSError *_Nonnull error) {
                if (!error) {
                  ;
                  [self->_loger
                              logObj:[[NSString alloc]
                                         initWithFormat:
                                             @"Batch request sent successfuly!"]
                      forDescription:kMappIntelligenceLogLevelDescriptionDebug];
                  [self->_dbManager removeRequestsDB:[self getRequestIDs:dt]];
                }
              handler(error);
              }];
        }
        if (bodies.count == 0) {
            handler(nil);
        }
    }];
}

- (NSArray<NSString *> *)createBatchWith:(MIRequestData *)data {
  NSMutableArray *array = [[NSMutableArray alloc] init];
    if(data.requests.count == 0) {
        return array;
    }
  NSMutableString *body = [[NSMutableString alloc] init];
  int i = 0;
  long requestsCount = data.requests.count;
  if (requestsCount > 10000) {
    [body setString:@""];
    long length =
        (requestsCount - i * 5000) > 5000 ? 5000 : (requestsCount - i * 5000);
    NSArray *subArray =
        [data.requests subarrayWithRange:NSMakeRange(i * 5000, length)];
    for (MIRequest *req in subArray) {
      [body appendString:@"wt?"];
      [body appendString:[[[req urlForBatchSupprot:YES] query] stringByReplacingOccurrencesOfString:@"\n" withString:@" "]];
      [body appendString:@"\n"];
    }
    [array addObject:body];
    i++;
  } else {
    for (MIRequest *req in data.requests) {
      [body appendString:@"wt?"];
      [body appendString:[[[req urlForBatchSupprot:YES] query] stringByReplacingOccurrencesOfString:@"\n" withString:@" "] ];
      [body appendString:@"\n"];
    }
    [array addObject:body];
  }
  return array;
}

-(NSArray* )getRequestIDs:(MIRequestData*) data {
    NSMutableArray* array = [[NSMutableArray alloc] init];
    for (MIRequest* req in data.requests) {
        [array addObject:req.uniqueId];
    }
    return array;
}


@end
