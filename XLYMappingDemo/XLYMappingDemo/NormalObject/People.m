//
//  People.m
//  XLYMappingDemo
//
//  Created by kaizei on 14/11/3.
//  Copyright (c) 2014年 kaizei. All rights reserved.
//

#import "People.h"

#import "Child.h"

@implementation People

- (instancetype)init
{
    if (self = [super init]) {
        self.children = [NSMutableSet setWithObject:[Child new]];
    }
    return self;
}

@end
