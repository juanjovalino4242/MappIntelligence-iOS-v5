//
//  Webrekk.h
//  Webrekk
//
//  Created by Stefan Stevanovic on 1/3/20.
//  Copyright © 2020 Stefan Stevanovic. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Webtrekk : NSObject
{}
+(id)sharedWebtrek;
+(void) setConfigurationWith: (NSDictionary *) dictionary;
@end
