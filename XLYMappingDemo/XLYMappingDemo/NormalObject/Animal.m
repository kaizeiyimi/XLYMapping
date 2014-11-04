//
//  Animal.m
//  XLYMappingDemo
//
//  Created by 王凯 on 14/11/3.
//  Copyright (c) 2014年 kaizei. All rights reserved.
//

#import "Animal.h"

#import "Dog.h"
#import "Cat.h"

@implementation Animal

+ (XLYObjectMapping *)defaultMapping
{
    XLYObjectMapping *mapping = [XLYObjectMapping mappingForClass:NSDictionary.class];
    XLYObjectMapping *dogMapping = [Dog defaultMapping];
    XLYObjectMapping *catMapping = [Cat defaultMapping];
    [mapping addRelationShipMapping:dogMapping fromKeyPath:@"dogs" toKey:@"dogs"];
    [mapping addMappingFromKeyPath:@"cats" toKey:@"cats" construction:^id(id JSONObject) {
        return [catMapping performSyncMappingWithJSONObject:JSONObject error:nil];
    }];
    return mapping;
}

+ (XLYObjectMapping *)dynamicMapping
{
    XLYObjectMapping *mapping = [XLYObjectMapping mappingForClass:nil];
    XLYObjectMapping *dogMapping = [Dog defaultMapping];
    XLYObjectMapping *catMapping = [Cat defaultMapping];
    mapping.dynamicMappingBlock = ^XLYObjectMapping *(id JSONObject) {
        if ([JSONObject[@"type"] isEqualToString:@"dog"]) {
            return dogMapping;
        } else if ([JSONObject[@"type"] isEqualToString:@"cat"]) {
            return catMapping;
        }
        return nil;
    };
    return mapping;
}

@end
