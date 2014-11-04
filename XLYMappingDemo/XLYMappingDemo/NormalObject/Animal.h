//
//  Animal.h
//  XLYMappingDemo
//
//  Created by 王凯 on 14/11/3.
//  Copyright (c) 2014年 kaizei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XLYObjectMapping.h"

@interface Animal : NSObject

@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) int32_t height;

+ (XLYObjectMapping *)defaultMapping;

+ (XLYObjectMapping *)dynamicMapping;

@end
