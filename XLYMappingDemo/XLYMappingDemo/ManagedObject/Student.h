//
//  Student.h
//  XLYMappingDemo
//
//  Created by 王凯 on 14/11/3.
//  Copyright (c) 2014年 kaizei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "XLYManagedObjectMapping.h"

#import "Person.h"

@class Teacher;

@interface Student : Person

@property (nonatomic) int32_t score;
@property (nonatomic, retain) Teacher *teacher;

+ (XLYMapping *)defaultMappingInManagedObjectContext:(NSManagedObjectContext *)context;

@end
