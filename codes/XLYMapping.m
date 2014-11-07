
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
NSInteger const XLYInvalidMappingManagedObjectPrimaryKeyErrorCode = -2;

static Class XLY_propertyTypeOfClass(Class theClass, NSString *propertyName);
static id XLY_adjustTransformedObject(id transformedObject, Class type, NSError **error);

@interface XLYMapNode ()

@property (nonatomic, copy) NSString *fromKeyPath;
@property (nonatomic, copy) NSString *toKey;
@property (nonatomic, strong) XLYMapping *mapping;
@property (nonatomic, copy) id(^construction)(id);
@property (nonatomic, copy) Class type;

@end

#pragma mark - XLYMapping
@interface XLYMapping ()

@property (nonatomic, strong) NSMutableDictionary *mappingConstraints;
@property (nonatomic, strong) NSMutableDictionary *mappingConstraints_toKeyVersion;
@property (nonatomic, strong) NSMutableDictionary *defaultValues;

@end

@implementation XLYMapping

- (instancetype)init
{
    if (self = [super init]) {
        self.mappingConstraints = [NSMutableDictionary new];
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
        node.mapping = mapping;
    } else {
        node.construction = construction;
    }
    return node;
}

- (void)addMappingNode:(XLYMapNode *)node
{
    NSAssert(!self.mappingConstraints[node.fromKeyPath], @"'%@' of class '%@' cannot map more than twice.", node.fromKeyPath, self.objectClass);
    NSAssert(!self.mappingConstraints_toKeyVersion[node.toKey], @"'%@' of class '%@' cannot be mapped more than twice.", node.toKey, self.objectClass);
    self.mappingConstraints[node.fromKeyPath] = node;
    self.mappingConstraints_toKeyVersion[node.toKey] = node;
}

- (void)fullfilMappingConstraintsWithJSONDict:(NSDictionary *)JSONDict
{
    NSMutableArray *keys = [JSONDict.allKeys mutableCopy];
    [keys removeObjectsInArray:self.mappingConstraints.allKeys];
    [keys removeObjectsInArray:self.mappingConstraints_toKeyVersion.allKeys];
    NSMutableArray *validKeys = [NSMutableArray arrayWithCapacity:keys.count];
    for (NSString *key in keys) {
        if (XLY_propertyTypeOfClass(self.objectClass, key)) {
            [validKeys addObject:key];
        }
    }
    if (validKeys.count) {
         [self addAttributeMappingFromArray:validKeys];
    }
}

#pragma mark methods can be overrided
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
        BOOL hasSetValidValue = NO;
        if (self.enablesAutoMap) {
            [self fullfilMappingConstraintsWithJSONDict:object];
        }
        for (XLYMapNode *node in self.mappingConstraints.allValues) {
            id value = [node transformForObjectClass:self.objectClass
                                           withValue:[object valueForKeyPath:node.fromKeyPath]
                                        defaultValue:self.defaultValues[node.toKey]
                                        rememberType:YES
                                               error:error];
            if (*error) {
                return nil;
            }
            if (value) {
                [resultObject setValue:value forKey:node.toKey];
                hasSetValidValue = YES;
            }
        }
        return hasSetValidValue ? resultObject : nil;
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
    NSAssert(false, @"'%@' cannot be used directly.", NSStringFromSelector(_cmd));
    return nil;
}

@end


#pragma mark - XLYMapNode implementation
@implementation XLYMapNode

- (id)transformForObjectClass:(Class)objectClass withValue:(id)value defaultValue:(id)defaultValue rememberType:(BOOL)rememberType error:(NSError **)error
{
    id result = nil;
    if (!value || [value isKindOfClass:[NSNull class]]) {
        result = defaultValue;
    } else {
        if (self.mapping) {
            result = [self.mapping transformForObject:value error:error];
        } else if (self.construction) {
            result = self.construction(value);
        } else {
            result = value;
        }
    }
    Class type;
    if (!rememberType) {
        type = XLY_propertyTypeOfClass(objectClass, self.toKey);
    } else {
        if (!self.type) {
            self.type = XLY_propertyTypeOfClass(objectClass, self.toKey);
        }
        type = self.type;
    }
    result = XLY_adjustTransformedObject(result, type, error);
    return result;
}

@end

#pragma mark - tool functions
static Class XLY_propertyTypeOfProperty(objc_property_t property)
{
    Class propertyClass = nil;
    static NSSet *numberTypeSet;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        numberTypeSet = [NSSet setWithObjects:@"NSNumber",@"c",@"i",@"s",@"l",@"q",@"C",@"I",@"S",@"L",@"Q",@"f",@"d",@"b",@"B",nil];
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
    } else if ([numberTypeSet containsObject:typeString]) {
        propertyClass = [NSNumber class];
    }
    return propertyClass;
}

static Class XLY_propertyTypeOfClass(Class theClass, NSString *propertyName)
{
    objc_property_t property = class_getProperty(theClass, propertyName.UTF8String);
    if ((theClass == [NSDictionary class] || theClass == [NSMutableDictionary class]) && !property) {
        return [NSObject class];
    }
    if (!property) {
        return nil;
    }
    return XLY_propertyTypeOfProperty(property);
}

static id XLY_adjustTransformedObject(id transformedObject, Class type, NSError *__autoreleasing *error)
{
    //将json中的null也当做没有值处理，将导致不设置该值
    if (!transformedObject || [transformedObject isKindOfClass:[NSNull class]]) {
        return nil;
    }
    static NSNumberFormatter *numberFormatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        numberFormatter = [NSNumberFormatter new];
    });
    id originTransformedObject = transformedObject;
    if (type == NSNumber.class) {   //number
        if ([transformedObject isKindOfClass:[NSString class]]) {
            transformedObject = [numberFormatter numberFromString:transformedObject];
        }
    } else if (type == NSString.class || type == NSMutableString.class) {   //string
        if ([transformedObject isKindOfClass:[NSNumber class]]) {
            transformedObject = [transformedObject stringValue];
        }
    } else if (type == NSURL.class) { //兼容string到URL的转换, 默认使用'URLWithString:'
        if ([transformedObject isKindOfClass:[NSString class]]) {
            transformedObject = [NSURL URLWithString:transformedObject];
        }
    }
    //兼容array到set的转换
    else if (type == NSSet.class || type == NSMutableSet.class) {
        if ([transformedObject isKindOfClass:[NSArray class]]) {
            transformedObject = [NSMutableSet setWithArray:transformedObject];
        }
    } else if (type == NSOrderedSet.class || type == NSMutableOrderedSet.class) {
        if ([transformedObject isKindOfClass:[NSArray class]]) {
            transformedObject = [[NSMutableOrderedSet alloc] initWithArray:transformedObject];
        }
    }
    if ([transformedObject respondsToSelector:@selector(mutableCopyWithZone:)]) {
        transformedObject = [transformedObject mutableCopy];
    }
    if (![transformedObject isKindOfClass:type] && error) {
        NSString *failureReason = [NSString stringWithFormat:@"transformed object cannot satisfy the destination type. object:%@, objectClass:%@, destinationType:%@", originTransformedObject, NSStringFromClass([transformedObject class]), type];
        *error = [NSError errorWithDomain:XLYInvalidMappingDomain
                                     code:XLYInvalidMappingTypeMismatchErrorCode
                                 userInfo:@{NSLocalizedFailureReasonErrorKey:failureReason}];
        return nil;
    }
    return transformedObject;
}

#pragma mark - debug description
@implementation XLYMapNode (DebugDescription)

- (NSString *)debugDescription
{
    NSMutableString *string = [[NSMutableString alloc] initWithFormat:@"['%@ -> %@', class:%@", self.fromKeyPath, self.toKey, self.type];
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
    return [self.mappingConstraints.allValues debugDescription];
}

@end
