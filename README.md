this Doc will show how to use XLYMapping system.
======

XLYMapping is designed to map JSON into local object.
the destination object can be object which inherited from NSObject or managedObject.

more details are shown below in the demo codes.
______

normal class mapping
------
## 'People' and 'Child' class defination
//defination of People class
    @interface People : NSObject
    @property (nonatomic, copy) NSString *name;
    @property (nonatomic, assign) double identity;
    @property (nonatomic, strong) NSMutableSet *kids;
    @end

//defination of Child class
    @interface Child : NSObject
    @property (nonatomic, copy) NSString *name;
    @property (nonatomic, assign) BOOL isMale;
    @end

## JSON example1
//this is a example. our JSON is:
    {"people_name":"kaizei",
    "more":{"id":123.45},
    "children":[
        {"child_name":"youzi", "sex":"boy"},
        {"child_name": "huolongguo", "sex": "girl"}
        ]
    }

## setup normal object mapping
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

    //this example is tested on iPhone 5s. it takes less than 0.8s to perform 10000 times.
    People *people = [peopleMapping performSyncMappingWithJSONObject:dict error:&error];


second example about managedObject mapping
------

## managed object 'Person' and 'Music' defination

    @interface Person : NSManagedObject
    @property (nonatomic, retain) NSString * name;
    @property (nonatomic, retain) NSSet *musics;
    @end

    @interface Music : NSManagedObject
    @property (nonatomic, retain) NSString * name;
    @property (nonatomic, retain) NSDate * createDate;
    @property (nonatomic, retain) Person *person;
    @end

## JSON example2
    //this time the JSON is:
    { "artist_name": "kaizei",
      "musics":[
        {"music_name": "youzi", "create_date": "2014-9-28"},
        {"music_name": "huolongguo", "create_date": "2014-9-29"}]
    }

## setup managed object mapping
    //setup Person mapping. set the name to be the primary key. we can set more than one.
    XLYManagedObjectMapping *personMapping = [XLYManagedObjectMapping mappingForClass:Person.class
                                                                           entityName:@"Person"
                                                                          primaryKeys:@[@"name"]
                                                                 managedObjectContext:self.context];
    [personMapping addAttributeMappingFromDict:@{@"artist_name":@"name"}];
    //setup Music mapping.
    XLYManagedObjectMapping *musicMapping = [XLYManagedObjectMapping mappingForClass:Music.class
                                                                          entityName:@"Music"
                                                                         primaryKeys:@[@"name"]
                                                                managedObjectContext:self.context];
    [musicMapping addAttributeMappingFromDict:@{@"music_name":@"name"}];
    //custom the date transform.
    [musicMapping addMappingFromKeyPath:@"create_date" toKey:@"createDate" construction:^id(id JSONObject) {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"yyyy-MM-dd";
        return [formatter dateFromString:JSONObject];
    }];
    //add relationship
    [personMapping addRelationShipMapping:musicMapping fromKeyPath:@"musics" toKey:@"musics"];
    //perform mapping async.
    [personMapping performAsyncMappingWithJSONObject:dict completion:^(id result, NSError *error) {
        //do anything your want.
        //NOTICE:no matter you perform mapping async or sync, it's always back to the context queue you give to the mapping.
    }];
