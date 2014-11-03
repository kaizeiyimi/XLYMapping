//
//  NormalObjectViewController.m
//  XLYMappingDemo
//
//  Created by 王凯 on 14/11/3.
//  Copyright (c) 2014年 kaizei. All rights reserved.
//

#import "NormalObjectViewController.h"

#import "Animal.h"
#import "People.h"
#import "Child.h"

@interface NormalObjectViewController ()

@end

@implementation NormalObjectViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self transformButtonClicked:nil];
}

- (IBAction)transformButtonClicked:(id)sender
{
    NSData *data = [NSData dataWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"People" withExtension:@"json"]];
    id JSONObject = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
    
    //setup people mapping.
    //name -> name, more.id -> identity.
    XLYObjectMapping *peopleMapping = [XLYObjectMapping mappingForClass:People.class];
    peopleMapping.willMapBlock = (id)^(id JSONObject) {
        //you can adjust the JSON here for any reason.
        //you can cancel this mapping by return nil.
        JSONObject = [JSONObject mutableCopy];
        JSONObject[@"name"] = JSONObject[@"people_name"];
        [JSONObject removeObjectForKey:@"people_name"];
        return JSONObject;
    };
    [peopleMapping addAttributeMappingFromArray:@[@"name"]];
    [peopleMapping addAttributeMappingFromDict:@{@"more.id":@"identity"}];
    //setup child mapping.
    //name -> name, isMale -> isBoy.
    XLYObjectMapping *childMapping = [XLYObjectMapping mappingForClass:Child.class];
    [childMapping addAttributeMappingFromDict:@{@"child_name":@"name"}];
    //custom transform sex to isMale.
    [childMapping addMappingFromKeyPath:@"sex" toKey:@"isMale" construction:^id(id JSONObject) {
        //you can also adjust any property. can also return nil.
        if ([[JSONObject lowercaseString] isEqualToString:@"boy"]) {
            return @YES;
        }
        return @NO;
    }];
    //add a relationship mapping from children to kids.
    [peopleMapping addRelationShipMapping:childMapping
                              fromKeyPath:@"children"
                                    toKey:@"kids"];
    
    //this example is tested on iPhone 5s. it takes less than 0.53s to perform 10,000 times.
    NSDate *date = [NSDate date];
    People *people;
    for (int i = 0; i < 10000; ++i) {
        people = [peopleMapping performSyncMappingWithJSONObject:JSONObject error:nil];
    }
    NSLog(@"cost time:%f", [[NSDate date] timeIntervalSinceDate:date]);
    NSLog(@"%@", people);
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
    NSDate *date = [NSDate date];
    NSArray *animals = [mapping performSyncMappingWithJSONObject:JSONObject error:nil];
    NSLog(@"cost time:%f", [[NSDate date] timeIntervalSinceDate:date]);
    NSLog(@"%@", animals);
}


@end
