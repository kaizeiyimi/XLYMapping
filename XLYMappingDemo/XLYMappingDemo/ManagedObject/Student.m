//
//  Student.m
//  XLYMappingDemo
//
//  Created by 王凯 on 14/11/3.
//  Copyright (c) 2014年 kaizei. All rights reserved.
//

#import "Student.h"
#import "Teacher.h"


@implementation Student

@dynamic score;
@dynamic teacher;

+ (XLYObjectMapping *)defaultMappingInManagedObjectContext:(NSManagedObjectContext *)context
{
    XLYManagedObjectMapping *mapping = [XLYManagedObjectMapping mappingForClass:self.class entityName:@"Student" primaryKeys:@[@"identity"] managedObjectContext:context];
    [mapping addAttributeMappingFromArray:@[@"identity",@"name",@"score"]];
    return mapping;
}

@end
