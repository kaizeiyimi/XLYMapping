//
//  NormalObjectViewController.m
//  XLYMappingDemo
//
//  Created by 王凯 on 14/11/3.
//  Copyright (c) 2014年 kaizei. All rights reserved.
//

#import "NormalObjectViewController.h"

#import "Animal.h"

@interface NormalObjectViewController ()

@end

@implementation NormalObjectViewController

- (IBAction)transformButtonClicked:(id)sender
{
    NSData *data = [NSData dataWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"Animals" withExtension:@"json"]];
    id JSONObject = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
    NSDictionary *animals = [[Animal defaultMapping] performSyncMappingWithJSONObject:JSONObject error:nil];
    NSLog(@"%@", animals);
}

- (IBAction)transformButton2Clicked:(id)sender
{
    NSData *data = [NSData dataWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"Animals" withExtension:@"json"]];
    id JSONObject = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
    XLYObjectMapping *mapping = [Animal dynamicMapping];
    __weak XLYObjectMapping *weakMapping = mapping;
    mapping.willMapBlock = ^id(id JSONObject) {
        if ([JSONObject isKindOfClass:[NSDictionary class]]) {
            NSMutableArray *array = [NSMutableArray new];
            for (NSString *key in [JSONObject allKeys]) {
                for (NSDictionary *animalInfo in JSONObject[key]) {
                    NSMutableDictionary *animal = [animalInfo mutableCopy];
                    animal[@"type"] = [key substringToIndex:key.length - 1];
                    [array addObject:animal];
                }
            }
            weakMapping.willMapBlock = nil;
            return array;
        }
        return JSONObject;
    };
    NSArray *animals = [mapping performSyncMappingWithJSONObject:JSONObject error:nil];
    NSLog(@"%@", animals);
}


@end
