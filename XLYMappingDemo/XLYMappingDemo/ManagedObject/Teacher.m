//
//  Teacher.m
//  XLYMappingDemo
//
//  Created by 王凯 on 14/11/3.
//  Copyright (c) 2014年 kaizei. All rights reserved.
//

#import "Teacher.h"
#import "Student.h"


@implementation Teacher

@dynamic schoolName;
@dynamic students;

+ (XLYObjectMapping *)defaultMappingInManagedObjectContext:(NSManagedObjectContext *)context
{
    XLYManagedObjectMapping *mapping = [XLYManagedObjectMapping mappingForClass:self.class entityName:@"Teacher" primaryKeys:@[@"identity"] managedObjectContext:context];
    [mapping addAttributeMappingFromArray:@[@"identity",@"name"]];
    [mapping addAttributeMappingFromDict:@{@"school name":@"schoolName"}];
    [mapping addRelationShipMapping:[Student defaultMappingInManagedObjectContext:context]
                        fromKeyPath:@"students"
                              toKey:@"students"];
    return mapping;
}

@end
