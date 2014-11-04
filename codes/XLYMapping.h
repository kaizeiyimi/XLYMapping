//
//  XLYMapping.h
//  XLYMappingDemo
//
//  Created by kaizei on 14/11/3.
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

@import Foundation;

@interface XLYMapping : NSObject

@property (nonatomic, copy) id(^willMapBlock)(id JSONObject);
@property (nonatomic, copy) XLYMapping *(^dynamicMappingBlock)(id JSONObject);

@property (nonatomic, strong) Class objectClass;

@property (nonatomic, assign) BOOL enablesAutoMap;

- (instancetype)init NS_REQUIRES_SUPER;

#pragma mark methods you should only use
///key is the fromKeyPath, value is the toKey.
- (void)addAttributeMappingFromDict:(NSDictionary *)dict;
///fromKeyPath and toKey is the same.
- (void)addAttributeMappingFromArray:(NSArray *)array;
///add your own construction block to perform transform. return nil to cancel this mapping.
- (void)addMappingFromKeyPath:(NSString *)fromKeyPath
                        toKey:(NSString *)toKey
                 construction:(id(^)(id JSONObject))construction;
///add a relationShip mapping.
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
