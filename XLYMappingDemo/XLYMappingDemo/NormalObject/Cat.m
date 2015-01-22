//
//  Cat.m
//  XLYMappingDemo
//
//  Created by 王凯 on 14/11/3.
//  Copyright (c) 2014年 kaizei. All rights reserved.
//

#import "Cat.h"

@implementation Cat

+ (XLYObjectMapping *)defaultMapping
{
    XLYObjectMapping *mapping = [XLYObjectMapping mappingForClass:self.class];
    [mapping addAttributeMappingFromArray:@[@"height"]];
    [mapping addAttributeMappingFromDict:@{@"name":@"name"}];
    [mapping addMappingFromKeyPath:@"eye color" toKey:@"eyeColor" construction:^id(id JSONObject) {
        NSArray *colorComponents = [JSONObject componentsSeparatedByString:@","];
        return [UIColor colorWithRed:[colorComponents[0] floatValue] / 255.0f
                               green:[colorComponents[1] floatValue] / 255.0f
                                blue:[colorComponents[2] floatValue] / 255.0f
                               alpha:[colorComponents[3] floatValue]];
    }];
    return mapping;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"CAT: name:%@, eyeColor:%@", self.name, self.eyeColor];
}

@end
