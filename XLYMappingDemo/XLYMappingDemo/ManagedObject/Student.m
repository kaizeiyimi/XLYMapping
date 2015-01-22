//
//  Student.m
//  XLYMappingDemo
//
//  Created by 王凯 on 14/11/3.
//  Copyright (c) 2014年 kaizei. All rights reserved.
//

#import "Student.h"


@implementation Student

@dynamic score;
@dynamic teacher;

+ (XLYMapping *)defaultMappingInManagedObjectContext:(NSManagedObjectContext *)context
{
    XLYManagedObjectMapping *mapping = [XLYManagedObjectMapping mappingForClass:self.class entityName:@"Student" primaryKeys:@[@"identity"] managedObjectContext:context];
    [mapping addAttributeMappingFromArray:@[@"identity",@"name",@"score"]];
    return mapping;
}

@end
