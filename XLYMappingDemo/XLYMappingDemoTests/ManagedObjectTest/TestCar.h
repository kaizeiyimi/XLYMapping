//
// Created by 王凯 on 15/1/22.
// Copyright (c) 2015 kaizei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@class TestPerson;
@interface TestCar : NSManagedObject

@property (nonatomic, copy) NSString *vendor;
@property (nonatomic, assign) int64_t identity;

@property (nonatomic, strong) TestPerson *person;

@end