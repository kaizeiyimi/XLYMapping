//
//  Teacher.h
//  XLYMappingDemo
//
//  Created by 王凯 on 14/11/3.
//  Copyright (c) 2014年 kaizei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "Person.h"
#import "XLYManagedObjectMapping.h"

@class Student;

@interface Teacher : Person

@property (nonatomic, retain) NSString * schoolName;
@property (nonatomic, retain) NSSet *students;

+ (XLYMapping *)defaultMappingInManagedObjectContext:(NSManagedObjectContext *)context;

@end

@interface Teacher (CoreDataGeneratedAccessors)

- (void)addStudentsObject:(Student *)value;
- (void)removeStudentsObject:(Student *)value;
- (void)addStudents:(NSSet *)values;
- (void)removeStudents:(NSSet *)values;

@end
