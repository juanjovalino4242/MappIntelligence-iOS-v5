//
//  EcommerceProperties.h
//  MappIntelligenceSDK
//
//  Created by Stefan Stevanovic on 26/10/2020.
//  Copyright © 2020 Mapp Digital US, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MIProduct.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, Status) {
    noneStatus,
    addedToBasket,
    purchased,
    viewed
};

@interface MIEcommerceProperties : NSObject

@property (nullable) NSArray<MIProduct*>* products;
@property (nonatomic) Status status;
@property (nullable) NSString* currency;
@property (nullable) NSString* orderID;
@property (nullable) NSNumber* orderValue;
//new values
@property (nullable) NSString* returningOrNewCustomer;
@property (nullable) NSNumber* returnValue;
@property (nullable) NSNumber* cancellationValue;
@property (nullable) NSNumber* couponValue;
@property (nullable) NSNumber* productAdvertiseID;
@property (nullable) NSNumber* productSoldOut;
@property (nullable) NSString* paymentMethod;
@property (nullable) NSString* shippingServiceProvider;
@property (nullable) NSString* shippingSpeed;
@property (nullable) NSNumber* shippingCost;
@property (nullable) NSNumber* markUp;
@property (nullable) NSString* productVariant;
@property (nullable) NSNumber* appInstalled;

@property (nullable) NSDictionary<NSNumber* ,NSArray<NSString*>*>* customProperties;

- (instancetype)initWithCustomProperties: (NSDictionary<NSNumber* ,NSArray<NSString*>*>* _Nullable) properties;
- (NSMutableArray<NSURLQueryItem*>*)asQueryItems;

@end

NS_ASSUME_NONNULL_END
