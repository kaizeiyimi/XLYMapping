
//  XLYMapping.m
//  XLYMappingDemo
//
//  Created by kaizei on 14/11/3.
//  Copyright (c) 2014年 kaizei. All rights reserved.
//

#import "XLYMapping.h"
#import "XLYMappingSubclasses.h"

#import <objc/runtime.h>

NSString * const XLYInvalidMappingDomain = @"XLYInvalidMappingDomain";
NSInteger const XLYInvalidMappingTypeMismatchErrorCode = -1;

static Class XLY_propertyTypeOfClass(Class theClass, NSString *propertyName, BOOL *isScalarType);
static BOOL XLY_isValidMappableProperty(Class theClass, NSString *propertyName);

@interface XLYMapNode ()

@property (nonatomic, copy) NSString *fromKeyPath;
@property (nonatomic, copy) NSString *toKey;
@property (nonatomic, strong) XLYMapping *mapping;
@property (nonatomic, copy) id(^construction)(id);
@property (nonatomic, strong) Class typeClass;
@property (nonatomic, assign) BOOL isScalarType; //typeClass 为NSNumber时有效,用以标识是否为基础类型

@property (nonatomic, strong) Class objectClass;

@end

#pragma mark - XLYMapping
@interface XLYMapping ()

@property (nonatomic, assign) XLYMapping *parentMapping;

@property (nonatomic, strong) NSMutableDictionary *mappingConstraints_fromKeyVersion;
@property (nonatomic, strong) NSMutableDictionary *mappingConstraints_toKeyVersion;
@property (nonatomic, strong) NSMutableDictionary *defaultValues;

@end

@implementation XLYMapping

- (instancetype)init
{
    if (self = [super init]) {
        self.mappingConstraints_fromKeyVersion = [NSMutableDictionary new];
        self.mappingConstraints_toKeyVersion = [NSMutableDictionary new];
        self.defaultValues = [NSMutableDictionary new];
    }
    return self;
}

#pragma mark public methods
- (void)addMappingFromKeyPath:(NSString *)fromKeyPath
                        toKey:(NSString *)toKey
                 construction:(id(^)(id JSONObject))construction
{
    XLYMapNode *node = [self mapNodeFromKeyPath:fromKeyPath toKey:toKey mapping:nil construction:construction];
    [self addMappingNode:node];
}

- (void)addAttributeMappingFromDict:(NSDictionary *)dict
{
    for (NSString *fromKeyPath in dict.allKeys) {
        XLYMapNode *node = [self mapNodeFromKeyPath:fromKeyPath toKey:dict[fromKeyPath] mapping:nil construction:nil];
        [self addMappingNode:node];
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

- (void)addRelationShipMapping:(XLYMapping *)mapping fromKeyPath:(NSString *)fromKeyPath toKey:(NSString *)toKey
{
    XLYMapNode *node = [self mapNodeFromKeyPath:fromKeyPath toKey:toKey mapping:mapping construction:nil];
    [self addMappingNode:node];
}

- (void)setDefaultValueForAttributes:(NSDictionary *)dict
{
    [self.defaultValues setValuesForKeysWithDictionary:dict];
}

#pragma mark private methods
- (XLYMapNode *)mapNodeFromKeyPath:(NSString *)fromKeyPath
                             toKey:(NSString *)toKey
                           mapping:(XLYMapping *)mapping
                      construction:(id(^)(id))construction
{
    NSAssert([toKey rangeOfString:@"."].location == NSNotFound, @"only support key not keyPath when set value for the result object.");
    XLYMapNode *node = [XLYMapNode new];
    node.fromKeyPath = fromKeyPath;
    node.toKey = toKey;
    if (mapping) {
        NSAssert(mapping.parentMapping == nil, @"one mapping object can only be added as relationship mapping once.");
        mapping.parentMapping = self;
        node.mapping = mapping;
    } else {
        node.construction = construction;
    }
    return node;
}

- (void)addMappingNode:(XLYMapNode *)node
{
    NSAssert(!self.mappingConstraints_fromKeyVersion[node.fromKeyPath], @"'%@' of class '%@' cannot map more than twice.", node.fromKeyPath, self.objectClass);
    NSAssert(!self.mappingConstraints_toKeyVersion[node.toKey], @"'%@' of class '%@' cannot be mapped more than twice.", node.toKey, self.objectClass);
    self.mappingConstraints_fromKeyVersion[node.fromKeyPath] = node;
    self.mappingConstraints_toKeyVersion[node.toKey] = node;
}

- (void)fulfillMappingConstraintsWithJSONDict:(NSDictionary *)JSONDict
{
    NSMutableArray *keys = [JSONDict.allKeys mutableCopy];
    [keys removeObjectsInArray:self.mappingConstraints_fromKeyVersion.allKeys];
    [keys removeObjectsInArray:self.mappingConstraints_toKeyVersion.allKeys];
    NSMutableArray *validKeys = [NSMutableArray arrayWithCapacity:keys.count];
    for (NSString *key in keys) {
        if (XLY_isValidMappableProperty(self.objectClass, key)) {
            [validKeys addObject:key];
        }
    }
    if (validKeys.count) {
         [self addAttributeMappingFromArray:validKeys];
    }
}

- (NSArray *)mappingConstraints
{
    return self.mappingConstraints_fromKeyVersion.allValues;
}

#pragma mark methods can be overridded
- (id)performSyncMappingWithJSONObject:(id)JSONObject error:(NSError *__autoreleasing *)error
{
    NSError *localError = nil;
    id object = [self transformForObject:JSONObject error:&localError];
    if (localError && error) {
        *error = localError;
    }
    return [object isKindOfClass:[NSNull class]] ? nil : object;
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
        return object;
    }
    if (self.willMapBlock) {
        object = self.willMapBlock(object);
    }
    if(!object || [object isKindOfClass:[NSNull class]]) {
        return object;
    }
    if ([object isKindOfClass:[NSDictionary class]]) {
        XLYMapping *mapping = self;
        if (self.dynamicMappingBlock) {
            mapping = self.dynamicMappingBlock(object);
        }
        if (mapping && mapping != self) {
            return [mapping transformForObject:object error:error];
        }
        id resultObject = [self getRawResultObjectForJSONDict:object error:error];
        if (!resultObject) {
            return nil;
        }
        if (self.enablesAutoMap) {
            [self fulfillMappingConstraintsWithJSONDict:object];
        }
        for (XLYMapNode *node in self.mappingConstraints) {
            id value = [node transformForObjectClass:self.objectClass
                                           withValue:[object valueForKeyPath:node.fromKeyPath]
                                        defaultValue:self.defaultValues[node.toKey]
                                               error:error];
            if (*error) {
                return nil;
            }
            if (value) {
                if ([value isKindOfClass:[NSNull class]]) {
                    [resultObject setValue:nil forKey:node.toKey];
                } else {
                    [resultObject setValue:value forKey:node.toKey];
                }
            }
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
    NSAssert(false, @"\"%@\" is not a valid mappable root json for class:'%@'.", object, NSStringFromClass(self.objectClass));
    return nil;
}

- (id)getRawResultObjectForJSONDict:(NSDictionary *)dict error:(NSError *__autoreleasing *)error
{
    NSAssert(false, @"'%@' cannot be used directly.", NSStringFromSelector(_cmd));
    return nil;
}

@end


#pragma mark - XLYMapNode implementation
@implementation XLYMapNode

- (id)transformForObjectClass:(Class)objectClass withValue:(id)value defaultValue:(id)defaultValue error:(NSError *__autoreleasing *)error
{
    if (!self.objectClass) {    //delays the confirmation of isScalarType, typeClass and objectClass here.
        self.objectClass = objectClass;
        BOOL isScalarType = NO;
        self.typeClass = XLY_propertyTypeOfClass(objectClass, self.toKey, &isScalarType);
        NSAssert(self.typeClass, @"class:'%@' does not contain a property named:'%@'.", NSStringFromClass(self.objectClass), self.toKey);
        self.isScalarType = isScalarType;
    }
    NSAssert(self.objectClass == objectClass, @"transfrom must always be performed for same objectClass. origin class:'%@' new class:'%@'", self.objectClass, objectClass);
    id result = nil;
    if (!value) {
        result = defaultValue;
    } else if ([value isKindOfClass:[NSNull class]]) {
        result = value;
    } else {
        if (self.mapping) {
            result = [self.mapping performSyncMappingWithJSONObject:value error:error];
        } else if (self.construction) {
            result = self.construction(value);
        } else {
            result = value;
        }
    }
    result = [self adjustTransformedObject:result error:error];
    return result;
}

- (id)adjustTransformedObject:(id)transformedObject error:(NSError **)error
{
    if (!transformedObject) {
        return nil;
    }
    if ([transformedObject isKindOfClass:[NSNull class]]) {
        if (self.typeClass == NSNumber.class && self.isScalarType) {
            return @0;
        } else {
            return transformedObject;
        }
    }
    static NSNumberFormatter *numberFormatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        numberFormatter = [NSNumberFormatter new];
    });
    id originTransformedObject = transformedObject;
    if (self.typeClass == NSNumber.class) {   //number
        if ([transformedObject isKindOfClass:[NSString class]]) {
            transformedObject = [numberFormatter numberFromString:transformedObject];
        }
    } else if (self.typeClass == NSString.class || self.typeClass == NSMutableString.class) {   //string
        if ([transformedObject isKindOfClass:[NSNumber class]]) {
            transformedObject = [transformedObject stringValue];
        }
    } else if (self.typeClass == NSURL.class) { //兼容string到URL的转换, 默认使用'URLWithString:'
        if ([transformedObject isKindOfClass:[NSString class]]) {
            transformedObject = [NSURL URLWithString:[transformedObject stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
        }
    }
    //兼容array到set的转换
    else if (self.typeClass == NSSet.class || self.typeClass == NSMutableSet.class) {
        if ([transformedObject isKindOfClass:[NSArray class]]) {
            transformedObject = [NSMutableSet setWithArray:transformedObject];
        }
    } else if (self.typeClass == NSOrderedSet.class || self.typeClass == NSMutableOrderedSet.class) {
        if ([transformedObject isKindOfClass:[NSArray class]]) {
            transformedObject = [[NSMutableOrderedSet alloc] initWithArray:transformedObject];
        }
    }
    if ([transformedObject respondsToSelector:@selector(mutableCopyWithZone:)]) {
        transformedObject = [transformedObject mutableCopy];
    }
    if (![transformedObject isKindOfClass:self.typeClass]) {
        if (error) {
            NSString *failureReason = [NSString stringWithFormat:@"transformed object cannot satisfy the destination type. fromKeyPath:\"%@\", toKey:\"%@\", transformedObject:\"%@\", transformedObjectType:\"%@\", destinationType:\"%@\"", self.fromKeyPath, self.toKey,originTransformedObject, NSStringFromClass([transformedObject class]), self.typeClass];
            *error = [NSError errorWithDomain:XLYInvalidMappingDomain
                                         code:XLYInvalidMappingTypeMismatchErrorCode
                                     userInfo:@{NSLocalizedFailureReasonErrorKey:failureReason}];
#ifdef DEBUG
        NSLog(@"XLYMappingError:%@", failureReason);
#endif
        }
        return nil;
    }
    return transformedObject;
}

@end

#pragma mark - tool functions
static Class XLY_propertyTypeOfProperty(objc_property_t property, BOOL *isScalarType)
{
    Class propertyClass = nil;
    static NSSet *numberTypeSet;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        numberTypeSet = [NSSet setWithObjects:@"c",@"i",@"s",@"l",@"q",@"C",@"I",@"S",@"L",@"Q",@"f",@"d",@"b",@"B",nil];
    });
    char *attr = property_copyAttributeValue(property, "T");
    NSString *typeString = [NSString stringWithCString:attr encoding:NSUTF8StringEncoding];
    free(attr);
    if ([typeString hasPrefix:@"@"]) { //oc中格式为@\xxx\,去掉前后的不需要的字符。swift中为@，保持NSObject
        if (typeString.length > 3) {
            typeString = [typeString substringWithRange:NSMakeRange(2, typeString.length - 3)];
            propertyClass = NSClassFromString(typeString);
            propertyClass = propertyClass ? propertyClass : [NSObject class];
        } else {
            propertyClass = [NSObject class];
        }
        if (isScalarType) {
            *isScalarType = NO;
        }
    } else if ([numberTypeSet containsObject:typeString]) {
        propertyClass = [NSNumber class];
        if (isScalarType) {
            *isScalarType = YES;
        }
    }
    return propertyClass;
}

static Class XLY_propertyTypeOfClass(Class theClass, NSString *propertyName, BOOL *isScalarType)
{
    objc_property_t property = class_getProperty(theClass, propertyName.UTF8String);
    if (isScalarType) {
        *isScalarType = NO;
    }
    if ((theClass == [NSDictionary class] || theClass == [NSMutableDictionary class]) && !property) {
        return [NSObject class];
    }
    if (!property) {
        return nil;
    }
    return XLY_propertyTypeOfProperty(property, isScalarType);
}

static BOOL XLY_isValidMappableProperty(Class theClass, NSString *propertyName)
{
    if (theClass == [NSDictionary class] || theClass == [NSMutableDictionary class]) {
        return YES;
    }
    objc_property_t property = class_getProperty(theClass, propertyName.UTF8String);
    return property != nil;
}

#pragma mark - debug description
@implementation XLYMapNode (DebugDescription)

- (NSString *)debugDescription
{
    NSMutableString *string = [[NSMutableString alloc] initWithFormat:@"['%@ -> %@', class:%@", self.fromKeyPath, self.toKey, self.typeClass];
    if (self.mapping) {
        [string appendFormat:@", relationShipMapping:%@", self.mapping.objectClass];
    }
    [string appendString:@"]"];
    return string;
}

@end

@implementation XLYMapping (DebugDescription)

- (NSString *)debugDescription
{
    return [self.mappingConstraints debugDescription];
}

@end
