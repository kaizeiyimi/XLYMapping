//
//  XLYMappingSubclasses.h
//  XLYMappingDemo
//
//  Created by kaizei on 14/11/3.
//  Copyright (c) 2014年 kaizei. All rights reserved.
//

#import "XLYMapping.h"

///make your own error if needed.
extern NSString * const XLYInvalidMappingDomain;
extern NSInteger const XLYInvalidMappingTypeMismatchErrorCode;
extern NSInteger const XLYInvalidMappingManagedObjectPrimaryKeyErrorCode;

#pragma mark - methods your subclass can override
@interface XLYMapping (Subclass)

///you must override this method to give mapping system an object to set values.
- (id)getRawResultObjectForJSONDict:(NSDictionary *)dict error:(NSError *__autoreleasing *)error;

@end

#pragma mark - methods you should not override but only call internal.
@interface XLYMapping ()

///transform json object. this object will call '-[getRawResultObjectForJSONDict:error:]'.
- (id)transformForObject:(id)object error:(NSError *__autoreleasing *)error;

///the mappingConstraints. key is fromKeyPath value is an instance of XLYMapNode.
- (NSDictionary *)mappingConstraints;

@end

#pragma mark - MapNode
@interface XLYMapNode : NSObject

@property (nonatomic, copy, readonly) NSString *fromKeyPath;
@property (nonatomic, copy, readonly) NSString *toKey;
@property (nonatomic, strong, readonly) XLYMapping *mapping;
@property (nonatomic, copy, readonly) id(^construction)(id);

///rememberType should be NO when temprory use.
- (id)transformForObjectClass:(Class)objectClass
                    withValue:(id)value
                 defaultValue:(id)defaultValue
                 rememberType:(BOOL)rememberType
                        error:(NSError **)error;

@end