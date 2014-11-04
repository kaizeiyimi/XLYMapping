//
//  XLYObjectMapping.m
//  XLYMapping
//
//  Created by 王凯 on 14-9-28.
//  Copyright (c) 2014年 kaizei. All rights reserved.
//

#import "XLYObjectMapping.h"
#import "XLYMappingSubclasses.h"

#pragma mark - XLYObjectMapping
@implementation XLYObjectMapping

+ (instancetype)mappingForClass:(Class)objectClass
{
    XLYObjectMapping *mapping = [self new];
    mapping.objectClass = objectClass;
    return mapping;
}

#pragma mark
- (id)getRawResultObjectForJSONDict:(NSDictionary *)dict error:(NSError *__autoreleasing *)error
{
    id object = [self.objectClass new];
    if ([object respondsToSelector:@selector(mutableCopyWithZone:)]) {
        object = [object mutableCopy];
    }
    return object;
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
    XLYManagedObjectMapping *mapping = [self new];
    mapping.objectClass = objectClass;
    mapping.entityName = entityName;
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

- (void)setDefaultValueForAttributes:(NSDictionary *)dict
{
    //delete default values for primary keys. primary keys cannot have default values.
    NSMutableDictionary *defaultValues = [dict mutableCopy];
    for (NSString *key in [dict.allKeys mutableCopy]) {
        if ([self.primaryKeys containsObject:key]) {
            [defaultValues removeObjectForKey:key];
        }
    }
    [super setDefaultValueForAttributes:defaultValues];
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
            id value = [node transformForObjectClass:self.objectClass
                                           withValue:[dict valueForKey:node.fromKeyPath]
                                        defaultValue:nil
                                        rememberType:NO
                                               error:error];
            if (*error) {
                return nil;
            }
            if (!value) {
                NSString *failureReason = [NSString stringWithFormat:@"the transformed value of primary key '%@' must not be nil.", node.toKey];
                *error = [NSError errorWithDomain:XLYInvalidMappingDomain
                                             code:XLYInvalidMappingManagedObjectPrimaryKeyErrorCode
                                         userInfo:@{NSLocalizedFailureReasonErrorKey:failureReason}];
                return nil;
            }
            predicateFragment[node.toKey] = value;
            primaryKeyCount++;
        }
    }
    if (self.primaryKeys.count != primaryKeyCount) {
        *error = [NSError errorWithDomain:XLYInvalidMappingDomain
                                     code:XLYInvalidMappingManagedObjectPrimaryKeyErrorCode
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
