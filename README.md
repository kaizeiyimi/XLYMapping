XLYMapping system.
======

XLYMapping is designed to map JSON into local object.
the destination object can be object which inherited from NSObject cause I use KVC to set values.

more details are shown below in the demo and test codes.

NOTICE: the mapping process is as follow:
------
1. will map. a chance to modify the JSON.
2. dynamic map. a change to give another mapping.
3. create a destination object. if failed then cancel the mapping.
4. transform property. a relationship mapping or construction block can replace the default transform.
5. validate transformed value. if failed then cancel the mapping.

the validate process is compatible for some specified types: number, string, set, orderedSet and URL. please read the code for more details.

#normal NSObject mapping

###'TestCat' and 'TestDog' class definition

```objective-c

    //definition of TestAnimal class
    @interface TestAnimal : NSObject
   
    @property (nonatomic, copy) NSString *name;
    @property (nonatomic, assign) NSInteger age;
    
    @end

    //definition of TestCat class
    @interface TestCat : TestAnimal
    
    @property (nonatomic, strong) UIColor *eyeColor;
    
    @end
    
    //definition of TestDog class
    @interface TestDog : TestAnimal
    
    @property (nonatomic, copy) NSURL *aboutLink;
    
    @end
```

### Animals.json
    //this is a example. our JSON is:
    {"dogs":[
      {
        "name":"DogA",
        "age":5,
        "about link":"http://link.to.DogA"
      },
      {
        "name":"DogB",
        "age":6,
        "about link":"http://link.to.DogB"
      }],
      "cats":[
        {
          "name":"CatC",
          "age":3,
          "eye color":"70,70,70,1"
        },
        {
          "name":"CatD",
          "age":4,
          "eye color":null
        }]
    }

###setup normal object mapping and transform

```objective-c

    //setup mapping.
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
     
    //perform transform
    NSDictionary *result = [mapping performSyncMappingWithJSONObject:JSONObject error:&error];
    //you will get a dictionary which has two keys of "dogs" and "cats". see test codes for more detail. 
```

#NSManagedObject mapping

###managed object 'TestPerson' and 'TestCar' definition

```objective-c

    //definition of TestPerson class
    @interface TestPerson : NSManagedObject
    
    @property (nonatomic, assign) int32_t identity;
    @property (nonatomic, copy) NSString *name;
    @property (nonatomic, assign) int32_t age;
    @property (nonatomic, strong) NSSet *cars;
    
    @end

    //definition of TestCar class
    @interface TestCar : NSManagedObject
    
    @property (nonatomic, copy) NSString *vendor;
    @property (nonatomic, assign) int64_t identity;
    @property (nonatomic, strong) TestPerson *person;
    
    @end
```

###Persons.json
    [
      {
        "name":"kaizei",
        "age":26,
        "id":1,
        "cars":[
          {
            "vendor":"lamborghini",
            "id":1001
          },
          {
            "vendor":"porsche",
            "id":1002
          }
        ]
      },
      {
        "name":"yimi",
        "age":25,
        "id":2,
        "cars":[
          {
            "vendor":"cadillac",
            "id":1003
          },
          {
            "vendor":"mercedes-benz",
            "id":1004
          }
        ]
      }
    ]

###setup managed object mapping and transform

```objective-c
    
    //create mappings.
    XLYManagedObjectMapping *carMapping = [XLYManagedObjectMapping mappingForClass:TestCar.class
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
    
    //transform json
    NSArray *result = [self.mapping performSyncMappingWithJSONObject:self.JSONObject error:&error];
    //you will get an array of two persons which are ManagedObject in 'self.context'.
```


dynamic mapping
======

###you can perform dynamic mapping if you need.
```objective-c
    //here we reuse the people mapping and child mapping.
    XLYObjectMapping *theMapping = [XLYObjectMapping mappingForClass:nil];

    theMapping.dynamicMappingBlock = ^XLYObjectMapping *(id JSONObject) {
        if (JSONObject[@"child_name"]) {
            return childMapping;
        }
        return peopleMapping;
    };
```

set default value
======
you can also set default value for missing values. if the system meets nil for some mapping, then the default value will be used, otherwise ignored. you can also check if the JSON is missing something using the willMapBlock, just check it, and if something missing, add some value.

the way to set default value is simple:

```objective-c
    [childMapping setDefaultValueForAttributes:@{@"isMale" : @YES}];
```
**NOTICE**: the key in dictionary is the **toKey**.


add relationship mapping for different kind of mappings
======
you can also add an managedObjectMapping as a relationship mapping of a normal NSObject mapping.
see `testManagedObjectMapping_embedded` test method for more detail.

you must notice that, not all different kind of mappings can be added as relationship mapping. it depends on concrete implementation.
for example, you can only add managedObjectMapping as relationship for a managedObjectMapping. 

support for swift
======

if you want to use this mapping system in swift. you must:

1. make your class inherit from NSObject, and support calling 'init()' method.
2. make every property Non-Optional and give every property a default value.

because our system uses KVC，but KVC in swift is not supported as well as in Objective-C.
you cannot use 'setValueForKey' for optional type.
