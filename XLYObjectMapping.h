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
 
 for more detail, please refer to the README.md file.
 */

#import <Foundation/Foundation.h>
@import CoreData;

#pragma mark - XLYObjectMapping
@interface XLYObjectMapping : NSObject

@property (nonatomic, copy) id(^willMapBlock)(id JSONObject);
@property (nonatomic, copy) XLYObjectMapping *(^dynamicMappingBlock)(id JSONObject);

+ (instancetype)mappingForClass:(Class)objectClass;

///key is the fromKeyPath, value is the toKey.
- (void)addAttributeMappingFromDict:(NSDictionary *)dict;
///fromKeyPath and toKey is the same.
- (void)addAttributeMappingFromArray:(NSArray *)array;
///add your own construction block to perform transform. return nil to cancel this mapping.
- (void)addMappingFromKeyPath:(NSString *)fromKeyPath
                        toKey:(NSString *)toKey
                 construction:(id(^)(id JSONObject))construction;
///add a relationShip mapping.
- (void)addRelationShipMapping:(XLYObjectMapping *)mapping
                   fromKeyPath:(NSString *)fromKeyPath
                         toKey:(NSString *)toKey;
///perform mapping synchronously, if an error occurs then return nil.
- (id)performSyncMappingWithJSONObject:(id)JSONObject error:(NSError **)error;
///perform mapping asynchronously, if an error occurs then the result in callback block will be nil.
- (void)performAsyncMappingWithJSONObject:(id)JSONObject completion:(void(^)(id result, NSError *error))completion;

///default value. key is the toKey not to fromKeyPath. this method is mainly used for attribute and not suggested for relationship.
- (void)setDefaultValueForAttributes:(NSDictionary *)dict;

@end

#pragma mark - XLYManagedObjectMapping
@interface XLYManagedObjectMapping : XLYObjectMapping

+ (instancetype)mappingForClass:(Class)objectClass
                     entityName:(NSString *)entityName
                    primaryKeys:(NSArray *)primaryKeys
           managedObjectContext:(NSManagedObjectContext *)parentContext;

///perform mapping synchronously, if an error occurs then return nil. the result will associated with parentContext.
- (id)performSyncMappingWithJSONObject:(id)JSONObject error:(NSError **)error;
///perform mapping asynchronously, if an error occurs then the result in callback block will be nil. the callback is in the parentContext's queue, and the result will associated with parentContext.
- (void)performAsyncMappingWithJSONObject:(id)JSONObject completion:(void(^)(id result, NSError *error))completion;

@end
