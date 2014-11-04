//
//  Cat.h
//  XLYMappingDemo
//
//  Created by 王凯 on 14/11/3.
//  Copyright (c) 2014年 kaizei. All rights reserved.
//

@import UIKit;

#import "Animal.h"
#import "XLYObjectMapping.h"

@interface Cat : Animal

@property (nonatomic, strong) UIColor *eyeColor;

+ (XLYObjectMapping *)defaultMapping;

@end
