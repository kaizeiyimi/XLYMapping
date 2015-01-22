//
//  XLYMapping.h
//  XLYMappingDemo
//
//  Created by kaizei on 14/11/3.
//  Copyright (c) 2014年 kaizei. All rights reserved.
//

/*
 valid JSON value can be:
 1. number(integer or float number) //corresponding to NSNumber
 2. boolean (true or false)         //also corresponding to NSNumber
 3. null                            //corresponding to NSNull
 4. string                          //corresponding to NSString
 5. array                           //corresponding to NSArray
 6. object                          //corresponding to NSDictionary
 
 for more detail, please refer to the README.md file.
 */

@import Foundation;

@interface XLYMapping : NSObject

@property (nonatomic, copy) id(^willMapBlock)(id JSONObject);
@property (nonatomic, copy) XLYMapping *(^dynamicMappingBlock)(id JSONObject);

@property (nonatomic, strong) Class objectClass;

/** Default is NO. set to YES to auto map json values into the destination object.
 *
 * It's important to known the fact that auto map can be much slow than normal map, because the mapping system has to find out the valid keys for your object. set to NO and add mappings yourself can make the mapping process faster.
 */
@property (nonatomic, assign) BOOL enablesAutoMap;
///the parentMapping is the mapping who adds the receiver as a relationship mapping.
@property (nonatomic, assign, readonly) XLYMapping *parentMapping;

- (instancetype)init;

#pragma mark methods you should only use
///key is the fromKeyPath, value is the toKey.
- (void)addAttributeMappingFromDict:(NSDictionary *)dict;
///fromKeyPath and toKey is the same.
- (void)addAttributeMappingFromArray:(NSArray *)array;
///add your own construction block to perform transform. return nil to cancel this mapping.
- (void)addMappingFromKeyPath:(NSString *)fromKeyPath
                        toKey:(NSString *)toKey
                 construction:(id(^)(id JSONObject))construction;
///add a relationShip mapping. one mapping object can only be added as relationship mapping once.
- (void)addRelationShipMapping:(XLYMapping *)mapping
                   fromKeyPath:(NSString *)fromKeyPath
                         toKey:(NSString *)toKey;

#pragma mark methods you can override if needed
/**
 * default value. key is the toKey not to fromKeyPath. this method is mainly used for attribute and not suggested for relationship.
 *
 * the value is not copied. you may use NSString, NSNumber .etc.
 */
- (void)setDefaultValueForAttributes:(NSDictionary *)dict;

///perform mapping synchronously, if an error occurs then return nil.
- (id)performSyncMappingWithJSONObject:(id)JSONObject error:(NSError **)error;
///perform mapping asynchronously, if an error occurs then the result in callback block will be nil.
- (void)performAsyncMappingWithJSONObject:(id)JSONObject completion:(void(^)(id result, NSError *error))completion;

@end
