//
//  XLYObjectMapping.h
//  XLYMapping
//
//  Created by 王凯 on 14-9-28.
//  Copyright (c) 2014年 kaizei. All rights reserved.
//

/*
 valid JSON value can be:
 1. number(integer or float number) //coresponding to NSNumber
 2. boolean (true or false)         //also coresponding to NSNumber
 3. null                            //coresponding to NSNull
 4. string                          //coresponding to NSString
 5. array                           //coresponding to NSArray
 6. object                          //coresponding to NSDictionary
 */

#import <Foundation/Foundation.h>
@import CoreData;

#pragma mark - XLYObjectMapping
@interface XLYObjectMapping : NSObject

@property (nonatomic, copy) id(^willMapBlock)(id JSONObject);
@property (nonatomic, copy) XLYObjectMapping *(^dynamicMappingBlock)(id JSONObject);

+ (instancetype)mappingForClass:(Class)objectClass;

- (void)addAttributeMappingFromDict:(NSDictionary *)dict;
- (void)addAttributeMappingFromArray:(NSArray *)array;

- (void)addMappingFromKeyPath:(NSString *)fromKeyPath
                        toKey:(NSString *)toKey
                 construction:(id(^)(id JSONObject))construction;

- (void)addRelationShipMapping:(XLYObjectMapping *)mapping
                   fromKeyPath:(NSString *)fromKeyPath
                         toKey:(NSString *)toKey;

- (id)performSyncMappingWithJSONObject:(id)JSONObject error:(NSError **)error;
- (void)performAsyncMappingWithJSONObject:(id)JSONObject completion:(void(^)(id result, NSError *error))completion;

@end

#pragma mark - XLYManagedObjectMapping
@interface XLYManagedObjectMapping : XLYObjectMapping

+ (instancetype)mappingForClass:(Class)objectClass
                     entityName:(NSString *)entityName
                    primaryKeys:(NSArray *)primaryKeys
           managedObjectContext:(NSManagedObjectContext *)parentContext;

- (id)performSyncMappingWithJSONObject:(id)JSONObject error:(NSError **)error;
- (void)performAsyncMappingWithJSONObject:(id)JSONObject completion:(void(^)(id result, NSError *error))completion;

@end
