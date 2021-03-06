//
//  XLYManagedObjectMapping.m
//  XLYMappingDemo
//
//  Created by 王凯 on 15/1/22.
//  Copyright (c) 2015年 kaizei. All rights reserved.
//

#import "XLYManagedObjectMapping.h"
#import "XLYMappingSubclasses.h"

@interface XLYManagedObjectMapping()

@property (nonatomic, copy) NSString *entityName;
@property (nonatomic, copy) NSArray *primaryKeys;
@property (nonatomic, strong) NSManagedObjectContext *context;

@end

@implementation XLYManagedObjectMapping

NSInteger const XLYInvalidMappingManagedObjectPrimaryKeyErrorCode = -3;

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

- (void)addRelationShipMapping:(XLYMapping *)mapping fromKeyPath:(NSString *)fromKeyPath toKey:(NSString *)toKey
{
    if (![mapping isKindOfClass:[XLYManagedObjectMapping class]]) {
        [NSException raise:@"XLYManagedObjectMappingInvaldConfig" format:@"relationShip mapping for managedObjectMapping must be XLYManagedObjectMapping."];
    }
    XLYManagedObjectMapping *theMapping = (XLYManagedObjectMapping *)mapping;
    if (theMapping.context.parentContext != self.context.parentContext) {
        [NSException raise:@"XLYManagedObjectMappingInvaldConfig" format:@"the MOCs of current mapping and relationShip mapping must have the same parent managedObjectContext."];
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
        if (localError) {
            resultObject = nil;
        } else if ((resultObject && ![resultObject isKindOfClass:[NSNull class]])
                   && ![self.parentMapping isKindOfClass:[XLYManagedObjectMapping class]]) {
            [self.context save:nil];
            NSArray *objectIDs;
            if ([resultObject isKindOfClass:[NSManagedObject class]]) {
                objectIDs = @[[resultObject objectID]];
            } else {    //array of MO
                objectIDs = [resultObject valueForKey:@"objectID"];
            }
            NSManagedObjectContext *parentContext = self.context.parentContext;
            [parentContext performBlockAndWait:^{
                NSMutableArray *objects = [NSMutableArray arrayWithCapacity:objectIDs.count];
                for (NSManagedObjectID *objectID in objectIDs) {
                    NSManagedObject *mo = [parentContext existingObjectWithID:objectID error:nil];
                    [objects addObject:mo];
                }
                if ([resultObject isKindOfClass:[NSArray class]]) {
                    resultObject = objects;
                } else {
                    resultObject = objects.firstObject;
                }
            }];
        }
    }];
    if (localError && error) {
        *error = localError;
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
    NSAssert(error, @"must give an inout error when finding the raw result object.");
    NSInteger primaryKeyCount = 0;
    NSMutableDictionary *predicateFragment = [NSMutableDictionary dictionary];
    for (XLYMapNode *node in self.mappingConstraints) {
        if ([self.primaryKeys containsObject:node.toKey]) {
            id value = [node transformForObjectClass:self.objectClass
                                           withValue:[dict valueForKey:node.fromKeyPath]
                                        defaultValue:nil
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
        if (error) {
            *error = [NSError errorWithDomain:XLYInvalidMappingDomain
                                         code:XLYInvalidMappingManagedObjectPrimaryKeyErrorCode
                                     userInfo:@{NSLocalizedFailureReasonErrorKey:@"all specified primary keys must also be mapped."}];
        }
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
