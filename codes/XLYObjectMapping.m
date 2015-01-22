//
//  XLYObjectMapping.m
//  XLYMapping
//
//  Created by 王凯 on 14-9-28.
//  Copyright (c) 2014年 kaizei. All rights reserved.
//

#import "XLYObjectMapping.h"
#import "XLYMappingSubclasses.h"

#pragma mark - XLYObjectMapping
@implementation XLYObjectMapping

+ (instancetype)mappingForClass:(Class)objectClass
{
    XLYObjectMapping *mapping = [self new];
    mapping.objectClass = objectClass;
    return mapping;
}

#pragma mark
- (id)getRawResultObjectForJSONDict:(NSDictionary *)dict error:(NSError *__autoreleasing *)error
{
    id object = [self.objectClass new];
    if ([object respondsToSelector:@selector(mutableCopyWithZone:)]) {
        object = [object mutableCopy];
    }
    return object;
}

@end
