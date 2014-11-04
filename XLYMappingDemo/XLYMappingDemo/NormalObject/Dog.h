//
//  Dog.h
//  XLYMappingDemo
//
//  Created by 王凯 on 14/11/3.
//  Copyright (c) 2014年 kaizei. All rights reserved.
//

#import "Animal.h"
#import "XLYObjectMapping.h"

@interface Dog : Animal

@property (nonatomic, strong) NSURL *aboutLink;

+ (XLYObjectMapping *)defaultMapping;

@end
