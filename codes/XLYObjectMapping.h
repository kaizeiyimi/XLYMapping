//
//  XLYObjectMapping.h
//  XLYMapping
//
//  Created by 王凯 on 14-9-28.
//  Copyright (c) 2014年 kaizei. All rights reserved.
//

#import "XLYMapping.h"

#pragma mark - XLYObjectMapping
@interface XLYObjectMapping : XLYMapping

+ (instancetype)mappingForClass:(Class)objectClass;

@end
