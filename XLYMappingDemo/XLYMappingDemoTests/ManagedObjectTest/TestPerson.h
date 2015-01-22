//
// Created by 王凯 on 15/1/22.
// Copyright (c) 2015 kaizei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface TestPerson : NSManagedObject

@property (nonatomic, assign) int32_t identity;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) int32_t age;

@property (nonatomic, strong) NSSet *cars;

@end