//
//  XLYManagedObjectMappingTest.m
//  XLYMappingDemo
//
//  Created by 王凯 on 15/1/22.
//  Copyright (c) 2015 kaizei. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import "TestPerson.h"
#import "TestCar.h"
#import "XLYObjectMapping.h"
#import "XLYManagedObjectMapping.h"

@interface XLYManagedObjectMappingTest : XCTestCase

@property (nonatomic, strong) NSManagedObjectContext *context;
@property (nonatomic, strong) XLYMapping *mapping;
@property (nonatomic, strong) id JSONObject;
@property (nonatomic, strong) id JSONObject2;

@end

@implementation XLYManagedObjectMappingTest

- (void)setUp {
    [super setUp];
    //context
    NSManagedObjectModel *model = [[NSManagedObjectModel alloc] initWithContentsOfURL:[[NSBundle bundleForClass:self.class] URLForResource:@"TestPersons" withExtension:@"momd"]];
    NSPersistentStoreCoordinator *coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
    [coordinator addPersistentStoreWithType:NSInMemoryStoreType
                              configuration:nil
                                        URL:nil
                                    options:nil
                                      error:nil];
    NSManagedObjectContext *context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    [context setPersistentStoreCoordinator:coordinator];
    [context setMergePolicy:NSMergeByPropertyStoreTrumpMergePolicy];
    self.context = context;
    //mapping
    XLYManagedObjectMapping *carMapping = [XLYManagedObjectMapping mappingForClass:TestCar .class
                                                                        entityName:@"Car"
                                                                       primaryKeys:@[@"identity"]
                                                              managedObjectContext:self.context];
    [carMapping addAttributeMappingFromDict:@{@"id":@"identity"}];
    [carMapping addAttributeMappingFromArray:@[@"vendor"]];
    XLYManagedObjectMapping *personMapping = [XLYManagedObjectMapping mappingForClass:TestPerson.class
                                                                           entityName:@"Person"
                                                                          primaryKeys:@[@"identity"]
                                                                 managedObjectContext:self.context];
    [personMapping addAttributeMappingFromDict:@{@"id":@"identity"}];
    [personMapping addAttributeMappingFromArray:@[@"name", @"age"]];
    [personMapping addRelationShipMapping:carMapping fromKeyPath:@"cars" toKey:@"cars"];
    self.mapping = personMapping;
    //json
    NSData *data = [NSData dataWithContentsOfURL:[[NSBundle bundleForClass:self.class] URLForResource:@"Persons" withExtension:@"json"]];
    id JSONObject = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
    self.JSONObject = JSONObject;

    data = [NSData dataWithContentsOfURL:[[NSBundle bundleForClass:self.class] URLForResource:@"Persons2" withExtension:@"json"]];
    JSONObject = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
    self.JSONObject2 = JSONObject;
}

- (void)tearDown {
    [super tearDown];
}

- (void)testManagedObjectMapping_insert {
    NSError *error;
    NSArray *result = [self.mapping performSyncMappingWithJSONObject:self.JSONObject error:&error];
    XCTAssert([result isKindOfClass:[NSArray class]] && result.count == 2);
    TestPerson *kaizei = [result filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(TestPerson *person, NSDictionary *bindings) {
        if (person.identity == 1) return YES;
        return NO;
    }]].firstObject;
    XCTAssertNotNil(kaizei);
    XCTAssertEqualObjects(kaizei.name, @"kaizei");
    XCTAssertEqual(kaizei.age, 26);
    NSArray *cars = kaizei.cars.allObjects;
    XCTAssert(cars.count == 2);
    for (TestCar *car in cars) {
        if (car.identity == 1001) {
            XCTAssertEqualObjects(car.vendor, @"lamborghini");
            continue;
        } else if (car.identity == 1002) {
            XCTAssertEqualObjects(car.vendor, @"porsche");
            continue;
        }
        XCTAssert(NO);
    }
}

- (void)testManagedObjectMapping_update {
    TestCar *car = [NSEntityDescription insertNewObjectForEntityForName:@"Car" inManagedObjectContext:self.context];
    car.identity = 1003;
    TestPerson *person = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:self.context];
    person.identity = 2;
    person.cars = [NSSet setWithObject:car];
    NSError *error = nil;
    [self.context save:&error];
    XCTAssertNil(error);

    NSArray *result = [self.mapping performSyncMappingWithJSONObject:self.JSONObject error:&error];
    TestPerson *person2 = [result filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(TestPerson *evaluatedObject, NSDictionary *bindings) {
        if (evaluatedObject.identity == 2) return YES;
        return NO;
    }]].firstObject;
    XCTAssertEqual(person, person2);
    XCTAssertEqualObjects(person.name, @"yimi");

    TestCar *car1003 = [person2.cars.allObjects filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(TestCar *evaluatedObject, NSDictionary *bindings) {
        if (evaluatedObject.identity == 1003) return YES;
        return NO;
    }]].firstObject;
    XCTAssertEqual(car, car1003);
    XCTAssertEqualObjects(car.vendor, @"cadillac");
}

- (void)testManagedObjectMapping_null {
    NSError *error;
    NSArray *result = [self.mapping performSyncMappingWithJSONObject:self.JSONObject error:&error];
    TestPerson *person1 = [result filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(TestPerson *evaluatedObject, NSDictionary *bindings) {
        if (evaluatedObject.identity == 1) return YES;
        return NO;
    }]].firstObject;
    XCTAssert(person1.cars.count == 2);

    TestPerson *person2 = [result filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(TestPerson *evaluatedObject, NSDictionary *bindings) {
        if (evaluatedObject.identity == 2) return YES;
        return NO;
    }]].firstObject;
    XCTAssert(person2.age == 25);
    XCTAssert(person2.cars.count == 2);
    //
    result = [self.mapping performSyncMappingWithJSONObject:self.JSONObject2 error:&error];
    TestPerson *person11 = [result filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(TestPerson *evaluatedObject, NSDictionary *bindings) {
        if (evaluatedObject.identity == 1) return YES;
        return NO;
    }]].firstObject;
    XCTAssertEqual(person1, person11);
    XCTAssert(person11.cars.count == 1);

    TestPerson *person12 = [result filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(TestPerson *evaluatedObject, NSDictionary *bindings) {
        if (evaluatedObject.identity == 2) return YES;
        return NO;
    }]].firstObject;
    XCTAssertEqual(person2, person12);
    XCTAssert(person12.age == 0);
    XCTAssert(person12.cars.count == 0);
}

- (void)testManagedObjectMapping_embedded {
    XLYMapping *rootMapping = [XLYObjectMapping mappingForClass:[NSDictionary class]];
    [rootMapping addAttributeMappingFromArray:@[@"totalCount"]];
    [rootMapping addRelationShipMapping:self.mapping fromKeyPath:@"persons" toKey:@"persons"];
    rootMapping.willMapBlock = ^id(NSArray *persons) {
        NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:2];
        dict[@"totalCount"] = @(persons.count);
        dict[@"persons"] = persons;
        return dict;
    };
    //
    NSError *error;
    NSDictionary *result = [rootMapping performSyncMappingWithJSONObject:self.JSONObject error:&error];
    XCTAssertEqualObjects(result[@"totalCount"], @2);
    NSArray *persons = result[@"persons"];
    XCTAssert(persons.count == 2);
    TestPerson *person = persons.firstObject;
    XCTAssert([person isKindOfClass:[NSManagedObject class]]);
    XCTAssertEqual(person.managedObjectContext, self.context);
    XCTAssert(person.cars.count == 2);
}

- (void)testManagedObjectMappingPerformance {
    // This is an example of a performance test case.
    __block NSError *error;
    [self.mapping performSyncMappingWithJSONObject:self.JSONObject error:&error];
    XCTAssertNil(error);
    [self measureBlock:^{
        for (int i = 0; i < 1000; ++i) {
            [self.mapping performSyncMappingWithJSONObject:self.JSONObject error:&error];
            XCTAssertNil(error);
        }
    }];
}

@end
