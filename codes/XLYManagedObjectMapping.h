//
//  XLYManagedObjectMapping.h
//  XLYMappingDemo
//
//  Created by 王凯 on 15/1/22.
//  Copyright (c) 2015年 kaizei. All rights reserved.
//

#import "XLYMapping.h"
#import <CoreData/CoreData.h>

extern NSInteger const XLYInvalidMappingManagedObjectPrimaryKeyErrorCode;

@interface XLYManagedObjectMapping : XLYMapping

+ (instancetype)mappingForClass:(Class)objectClass
                     entityName:(NSString *)entityName
                    primaryKeys:(NSArray *)primaryKeys
           managedObjectContext:(NSManagedObjectContext *)parentContext;

///perform mapping synchronously, if an error occurs then return nil. the result will associated with parentContext.
- (id)performSyncMappingWithJSONObject:(id)JSONObject error:(NSError **)error;
///perform mapping asynchronously, if an error occurs then the result in callback block will be nil. the callback is in the parentContext's queue, and the result will associated with parentContext.
- (void)performAsyncMappingWithJSONObject:(id)JSONObject completion:(void(^)(id result, NSError *error))completion;

@end

