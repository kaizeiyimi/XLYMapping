//
//  XLYObjectMapping.m
//  XLYMapping
//
//  Created by 王凯 on 14-9-28.
//  Copyright (c) 2014年 kaizei. All rights reserved.
//

#import "XLYObjectMapping.h"
#import <objc/runtime.h>

static NSString * const XLYInvalidMappingDomain = @"XLYInvalidMappingDomain";

#pragma mark - MapNode
@interface XLYMapNode : NSObject

@property (nonatomic, copy) NSString *fromKeyPath;
@property (nonatomic, copy) NSString *toKey;
@property (nonatomic, strong) XLYObjectMapping *mapping;
@property (nonatomic, copy) id(^construction)(id);
@property (nonatomic, copy) NSString *type;

- (id)transformForObject:(id)object error:(NSError **)error;

@end

static NSString * XLY_propertyTypeStringOfClass(Class theClass, NSString *propertyName);
static id XLY_adjustTransformedObject(id transformedObject, NSString *type, NSError **error);

#pragma mark - XLYObjectMapping
@interface XLYObjectMapping ()

@property (nonatomic, strong) NSMutableDictionary *mappingConstraints;
@property (nonatomic, strong) Class objectClass;

@end

@implementation XLYObjectMapping

+ (instancetype)mappingForClass:(Class)objectClass
{
    XLYObjectMapping *mapping = [self new];
    mapping.objectClass = objectClass;
    mapping.mappingConstraints = [NSMutableDictionary new];
    return mapping;
}

- (XLYMapNode *)mapNodeFromKeyPath:(NSString *)fromKeyPath
                             toKey:(NSString *)toKey
                           mapping:(XLYObjectMapping *)mapping
                      construction:(id(^)(id))construction
{
    NSAssert([toKey rangeOfString:@"."].location == NSNotFound, @"only support key not keyPath when set value for the result object.");
    XLYMapNode *node = [XLYMapNode new];
    node.fromKeyPath = fromKeyPath;
    node.toKey = toKey;
    if (mapping) {
        node.mapping = mapping;
    } else {
        node.construction = construction;
    }
    node.type = XLY_propertyTypeStringOfClass(self.objectClass, node.toKey);
    return node;
}

- (void)addMappingFromKeyPath:(NSString *)fromKeyPath
                        toKey:(NSString *)toKey
                 construction:(id(^)(id JSONObject))construction
{
    XLYMapNode *node = [self mapNodeFromKeyPath:fromKeyPath toKey:toKey mapping:nil construction:construction];
    self.mappingConstraints[fromKeyPath] = node;
}

- (void)addAttributeMappingFromDict:(NSDictionary *)dict
{
    for (NSString *fromKeyPath in dict.allKeys) {
        XLYMapNode *node = [self mapNodeFromKeyPath:fromKeyPath toKey:dict[fromKeyPath] mapping:nil construction:nil];
        self.mappingConstraints[fromKeyPath] = node;
    }
}

- (void)addAttributeMappingFromArray:(NSArray *)array
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:array.count];
    for (NSString *keyPath in array) {
        dict[keyPath] = keyPath;
    }
    [self addAttributeMappingFromDict:dict];
}

- (void)addRelationShipMapping:(XLYObjectMapping *)mapping fromKeyPath:(NSString *)fromKeyPath toKey:(NSString *)toKey
{
    XLYMapNode *node = [self mapNodeFromKeyPath:fromKeyPath toKey:toKey mapping:mapping construction:nil];
    self.mappingConstraints[fromKeyPath] = node;
}

#pragma mark
- (id)performSyncMappingWithJSONObject:(id)JSONObject error:(NSError *__autoreleasing *)error
{
    NSError *localError = nil;
    id object = [self transformForObject:JSONObject error:&localError];
    if (localError) {
        if (error) {
            *error = localError;
        }
    }
    return object;
}

- (void)performAsyncMappingWithJSONObject:(id)JSONObject completion:(void(^)(id, NSError *))completion
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error;
        id resultObject = [self performSyncMappingWithJSONObject:JSONObject error:&error];
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(resultObject, error);
            });
        }
    });
}

- (id)transformForObject:(id)object error:(NSError *__autoreleasing *)error
{
    if(!object || [object isKindOfClass:[NSNull class]]) {
        return nil;
    }
    if (self.willMapBlock) {
        object = self.willMapBlock(object);
    }
    if (!object) {
        return nil;
    }
    if ([object isKindOfClass:[NSDictionary class]]) {
        id resultObject = [self getRawResultObjectForJSONDict:object error:error];
        if (!resultObject) {
            return nil;
        }
        for (XLYMapNode *node in self.mappingConstraints.allValues) {
            id value = [node transformForObject:[object valueForKeyPath:node.fromKeyPath] error:error];
            if (*error) {
                return nil;
            }
            [resultObject setValue:value forKey:node.toKey];
        }
        return resultObject;
    } else if ([object isKindOfClass:[NSArray class]]) {
        NSMutableArray *resultArray = [NSMutableArray arrayWithCapacity:[object count]];
        for (id item in object) {
            id value = [self transformForObject:item error:error];
            if (*error) {
                return nil;
            }
            if (value) {
                [resultArray addObject:value];
            }
        }
        return resultArray.count > 0 ? resultArray : nil;
    }
    NSAssert(false, @"not a valid json object.");
    return nil;
}

- (id)getRawResultObjectForJSONDict:(NSDictionary *)dict error:(NSError *__autoreleasing *)error
{
    return [self.objectClass new];
}

@end

#pragma mark - XLYManagedObjectMapping
@interface XLYManagedObjectMapping()

@property (nonatomic, copy) NSString *entityName;
@property (nonatomic, copy) NSArray *primaryKeys;
@property (nonatomic, strong) NSManagedObjectContext *context;

@end

@implementation XLYManagedObjectMapping

+ (instancetype)mappingForClass:(Class)objectClass
{
    [NSException raise:@"XLYManagedObjectMappingInvalidInitialization" format:@"managed object mapping must give an entity name and a managedObjectContext.\n \
     use '+ (instancetype)mappingForClass:(Class)objectClass entityName:(NSString *)entityName primaryKeys:(NSArray *)primaryKeys managedObjectContext:(NSManagedObjectContext *)parentContext' instead."];
    return nil;
}

+ (instancetype)mappingForClass:(Class)objectClass
                     entityName:(NSString *)entityName
                    primaryKeys:(NSArray *)primaryKeys
           managedObjectContext:(NSManagedObjectContext *)parentContext
{
    XLYManagedObjectMapping *mapping = [XLYManagedObjectMapping new];
    mapping.mappingConstraints = [NSMutableDictionary new];
    mapping.entityName = entityName;
    mapping.objectClass = objectClass;
    mapping.primaryKeys = primaryKeys;
    NSManagedObjectContext *context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    context.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy;
    context.parentContext = parentContext;
    mapping.context = context;
    [[NSNotificationCenter defaultCenter] addObserver:mapping selector:@selector(parentContextDidSave:) name:NSManagedObjectContextDidSaveNotification object:parentContext];
    return mapping;
}

- (void)parentContextDidSave:(NSNotification *)notify
{
    [self.context mergeChangesFromContextDidSaveNotification:notify];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSManagedObjectContextDidSaveNotification
                                                  object:self.context.parentContext];
}

- (void)addRelationShipMapping:(XLYObjectMapping *)mapping fromKeyPath:(NSString *)fromKeyPath toKey:(NSString *)toKey
{
    if (![mapping isKindOfClass:[XLYManagedObjectMapping class]]) {
        [NSException raise:@"XLYManagedObjectMappingInvaldConfig" format:@"relationShip mapping for managedObjectMapping must be XLYManagedObjectMapping."];
        return;
    }
    XLYManagedObjectMapping *theMapping = (XLYManagedObjectMapping *)mapping;
    if (theMapping.context.parentContext != self.context.parentContext) {
        [NSException raise:@"XLYManagedObjectMappingInvaldConfig" format:@"the MOCs of current mapping and relationShip mapping must have the same parent managedObjectContext."];
        return;
    }
    [[NSNotificationCenter defaultCenter] removeObserver:theMapping
                                                    name:NSManagedObjectContextDidSaveNotification
                                                  object:theMapping.context.parentContext];
    theMapping.context = self.context;
    [super addRelationShipMapping:mapping fromKeyPath:fromKeyPath toKey:toKey];
}

- (id)performSyncMappingWithJSONObject:(id)JSONObject error:(NSError *__autoreleasing *)error
{
    __block NSError *localError = nil;
    __block id resultObject;
    [self.context performBlockAndWait:^{
        resultObject = [self transformForObject:JSONObject error:&localError];
        [self.context save:nil];
        NSArray *objectIDs;
        if ([resultObject isKindOfClass:[NSManagedObject class]]) {
            objectIDs = @[[resultObject objectID]];
        } else {
            objectIDs = [resultObject valueForKey:@"objectID"];
        }
        NSManagedObjectContext *parentContext = self.context.parentContext;
        [parentContext performBlockAndWait:^{
            NSMutableArray *objects = [NSMutableArray arrayWithCapacity:objectIDs.count];
            for (NSManagedObjectID *objectID in objectIDs) {
                NSManagedObject *mo = [parentContext existingObjectWithID:objectID error:nil];
                [objects addObject:mo];
            }
            if (objects.count == 1) {
                resultObject = objects.firstObject;
            } else {
                resultObject = objects;
            }
        }];
    }];
    if (localError) {
        if (error) {
            *error = localError;
        }
    }
    return resultObject;
}

- (void)performAsyncMappingWithJSONObject:(id)JSONObject completion:(void (^)(id, NSError *))completion
{
    [self.context performBlock:^{
        NSError *error;
        id resultObject = [self performSyncMappingWithJSONObject:JSONObject error:&error];
        if (completion) {
            [self.context.parentContext performBlock:^{
                completion(resultObject, error);
            }];
        }
    }];
}

- (id)getRawResultObjectForJSONDict:(NSDictionary *)dict error:(NSError *__autoreleasing *)error
{
    NSAssert(error, @"must give an inout error to find the raw result object.");
    NSInteger primaryKeyCount = 0;
    NSMutableDictionary *predicateFragment = [NSMutableDictionary dictionary];
    for (XLYMapNode *node in self.mappingConstraints.allValues) {
        if ([self.primaryKeys containsObject:node.toKey]) {
            id value = [node transformForObject:[dict valueForKey:node.fromKeyPath] error:error];
            if (*error) {
                return nil;
            }
            if (!value) {
                NSString *failureReason = [NSString stringWithFormat:@"the transformed value of primary key '%@' must not be nil.", node.toKey];
                *error = [NSError errorWithDomain:XLYInvalidMappingDomain code:-2 userInfo:@{NSLocalizedFailureReasonErrorKey:failureReason}];
                return nil;
            }
            predicateFragment[node.toKey] = value;
            primaryKeyCount++;
        }
    }
    if (self.primaryKeys.count != primaryKeyCount) {
        *error = [NSError errorWithDomain:XLYInvalidMappingDomain
                                     code:-2
                                 userInfo:@{NSLocalizedFailureReasonErrorKey:@"all specified primary keys must also be mapped."}];
        return nil;
    }
    id resultObject;
    if (predicateFragment.count > 0) {
        NSMutableArray *array = [NSMutableArray arrayWithCapacity:predicateFragment.allKeys.count];
        for (NSString *key in predicateFragment.allKeys) {
            [array addObject:[[NSString alloc] initWithFormat:@"(%@ = $%@)", key, key]];
        }
        NSString *format = [array componentsJoinedByString:@" AND "];
        NSPredicate *predicate = [[NSPredicate predicateWithFormat:format] predicateWithSubstitutionVariables:predicateFragment];
        NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:self.entityName];
        request.predicate = predicate;
        resultObject = [self.context executeFetchRequest:request error:nil].firstObject;
    }
    if (!resultObject) {
        resultObject = [NSEntityDescription insertNewObjectForEntityForName:self.entityName inManagedObjectContext:self.context];
    }
    return resultObject;
}

@end

#pragma mark - XLYMapNode implementation
@implementation XLYMapNode

- (id)transformForObject:(id)object error:(NSError * __autoreleasing *)error
{
    id resultObject = nil;
    if (self.mapping) {
        resultObject = [self.mapping transformForObject:object error:error];
    } else if (self.construction) {
            resultObject = self.construction(object);
    } else {
        resultObject = object;
    }
    resultObject = XLY_adjustTransformedObject(resultObject, self.type, error);
    return resultObject;
}

@end

#pragma mark - tool functions
static NSString * XLY_propertyTypeStringOfProperty(objc_property_t property)
{
    char *attr = property_copyAttributeValue(property, "T");
    NSString *typeString = [NSString stringWithCString:attr encoding:NSUTF8StringEncoding];
    if ([typeString hasPrefix:@"@"]) {  //格式为@\xxx\,去掉前后的不需要的字符
        typeString = [typeString substringWithRange:NSMakeRange(2, typeString.length - 3)];
    }
    free(attr);
    return typeString;
}

static NSString * XLY_propertyTypeStringOfClass(Class theClass, NSString *propertyName)
{
    objc_property_t property = class_getProperty(theClass, propertyName.UTF8String);
    NSString *typeString = XLY_propertyTypeStringOfProperty(property);
    return typeString;
}

static id XLY_adjustTransformedObject(id transformedObject, NSString *type, NSError *__autoreleasing *error)
{
    if (!transformedObject || [transformedObject isKindOfClass:[NSNull class]]) {
        return nil;
    }
    static NSSet *numberTypeSet;
    static NSNumberFormatter *numberFormatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        numberTypeSet = [NSSet setWithObjects:@"NSNumber",@"c",@"i",@"s",@"l",@"q",@"C",@"I",@"S",@"L",@"Q",@"f",@"d",@"b",@"B",nil];
        numberFormatter = [NSNumberFormatter new];
    });
    id originTransformedObject = transformedObject;
    if ([numberTypeSet containsObject:type]) {   //number
        type = NSStringFromClass(NSNumber.class);
        if ([transformedObject isKindOfClass:[NSString class]]) {
            transformedObject = [numberFormatter numberFromString:transformedObject];
        }
    } else if ([type isEqualToString:NSStringFromClass(NSString.class)]
               || [type isEqualToString:NSStringFromClass(NSMutableString.class)]) {   //string
        if ([transformedObject isKindOfClass:[NSNumber class]]) {
            transformedObject = [transformedObject stringValue];
        }
    }
    //兼容array到set的转换
      else if ([type isEqualToString:NSStringFromClass(NSSet.class)]
               || [type isEqualToString:NSStringFromClass(NSMutableSet.class)]) {
          if ([transformedObject isKindOfClass:[NSArray class]]) {
            transformedObject = [NSMutableSet setWithArray:transformedObject];
        }
    } else if ([type isEqualToString:NSStringFromClass(NSOrderedSet.class)]
               || [type isEqualToString:NSStringFromClass(NSMutableOrderedSet.class)]) {
        if ([transformedObject isKindOfClass:[NSArray class]]) {
            transformedObject = [[NSMutableOrderedSet alloc] initWithArray:transformedObject];
        }
    }
    if ([transformedObject respondsToSelector:@selector(mutableCopyWithZone:)]) {
        transformedObject = [transformedObject mutableCopy];
    }
    if (![transformedObject isKindOfClass:NSClassFromString(type)] && error) {
        NSString *failureReason = [NSString stringWithFormat:@"transformed object cannot satisfy the destination type. object:%@, objectClass:%@, destinationType:%@", originTransformedObject, NSStringFromClass([transformedObject class]), type];
        *error = [NSError errorWithDomain:XLYInvalidMappingDomain
                                     code:-1
                                 userInfo:@{NSLocalizedFailureReasonErrorKey:failureReason}];
    }
    return transformedObject;
}
