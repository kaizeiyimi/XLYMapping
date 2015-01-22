//
//  XLYNormalObjectMappingTest.m
//  XLYMappingDemo
//
//  Created by 王凯 on 15/1/22.
//  Copyright (c) 2015 kaizei. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import "TestCat.h"
#import "TestDog.h"
#import "XLYObjectMapping.h"

@interface XLYNormalObjectMappingTest : XCTestCase

@end

@implementation XLYNormalObjectMappingTest

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (XLYMapping *)generateAnimalMapping
{
    XLYObjectMapping *dogMapping = [XLYObjectMapping mappingForClass:[TestDog class]];
    [dogMapping addAttributeMappingFromArray:@[@"name", @"age"]];
    [dogMapping addAttributeMappingFromDict:@{@"about link":@"aboutLink"}];

    XLYObjectMapping *catMapping = [XLYObjectMapping mappingForClass:[TestCat class]];
    [catMapping addAttributeMappingFromArray:@[@"name", @"age"]];
    [catMapping addMappingFromKeyPath:@"eye color" toKey:@"eyeColor" construction:^id(id JSONObject) {
        NSArray *colorComponents = [JSONObject componentsSeparatedByString:@","];
        return [UIColor colorWithRed:[colorComponents[0] floatValue] / 255.0f
                               green:[colorComponents[1] floatValue] / 255.0f
                                blue:[colorComponents[2] floatValue] / 255.0f
                               alpha:[colorComponents[3] floatValue]];
    }];

    XLYMapping *mapping = [XLYObjectMapping mappingForClass:[NSDictionary class]];
    [mapping addRelationShipMapping:dogMapping fromKeyPath:@"dogs" toKey:@"dogs"];
    [mapping addRelationShipMapping:catMapping fromKeyPath:@"cats" toKey:@"cats"];

    return mapping;
}

- (void)testAnimalMapping {
    //read the json‰
    NSData *data = [NSData dataWithContentsOfURL:[[NSBundle bundleForClass:self.class] URLForResource:@"Animals" withExtension:@"json"]];
    id JSONObject = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];

    XLYMapping *mapping = [self generateAnimalMapping];
    NSError *error;
    NSDictionary *result = [mapping performSyncMappingWithJSONObject:JSONObject error:&error];

    XCTAssert([result isKindOfClass:[NSDictionary class]]);
    XCTAssert([result[@"dogs"] isKindOfClass:[NSArray class]] && [result[@"dogs"] count] == 2);
    XCTAssert([result[@"cats"] isKindOfClass:[NSArray class]] && [result[@"cats"] count] == 2);

    for (TestDog *dog in result[@"dogs"]) {
        XCTAssert([dog.name isKindOfClass:[NSString class]] && dog.name.length > 0);
        XCTAssert(dog.age > 0);
        XCTAssert([dog.aboutLink isKindOfClass:[NSURL class]] && dog.aboutLink.absoluteString.length > 0);
    }

    for (TestCat *cat in result[@"cats"]) {
        XCTAssert([cat.name isKindOfClass:[NSString class]] && cat.name.length > 0);
        XCTAssert(cat.age > 0);
        if ([cat.name isEqualToString:@"CatC"]) {
            CGFloat metric = 70.0f / 255;
            XCTAssertEqualObjects(cat.eyeColor, [UIColor colorWithRed:metric green:metric blue:metric alpha:1]);
        } else if ([cat.name isEqualToString:@"CatD"]) {
            XCTAssertNil(cat.eyeColor);
        }
    }
}

- (void)testPerformanceExample {
    NSData *data = [NSData dataWithContentsOfURL:[[NSBundle bundleForClass:self.class] URLForResource:@"Animals" withExtension:@"json"]];
    id JSONObject = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
    XLYMapping *mapping = [self generateAnimalMapping];
    [self measureBlock:^{
        for (int i = 0; i < 1000; ++i) {
            NSError *error;
            [mapping performSyncMappingWithJSONObject:JSONObject error:&error];
        }
    }];
}

@end
