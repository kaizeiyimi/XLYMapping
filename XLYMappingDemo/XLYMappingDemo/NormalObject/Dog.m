//
//  Dog.m
//  XLYMappingDemo
//
//  Created by 王凯 on 14/11/3.
//  Copyright (c) 2014年 kaizei. All rights reserved.
//

#import "Dog.h"

@implementation Dog

+ (XLYObjectMapping *)defaultMapping
{
    XLYObjectMapping *mapping = [XLYObjectMapping mappingForClass:self.class];
    [mapping addAttributeMappingFromArray:@[@"name", @"height"]];
    [mapping addAttributeMappingFromDict:@{@"link":@"aboutLink"}];
    return mapping;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"DOG: name:%@, aboutLink:%@", self.name, self.aboutLink];
}

@end
