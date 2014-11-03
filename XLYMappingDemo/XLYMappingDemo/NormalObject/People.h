//
//  People.h
//  XLYMappingDemo
//
//  Created by kaizei on 14/11/3.
//  Copyright (c) 2014年 kaizei. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface People : NSObject

@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) double identity;
@property (nonatomic, strong) NSMutableSet *kids;

@end
