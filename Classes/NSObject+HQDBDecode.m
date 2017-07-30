//
//  NSObject+HQDBDecode.m
//  HQModelDemo
//
//  Created by 刘欢庆 on 2017/4/11.
//  Copyright © 2017年 刘欢庆. All rights reserved.
//

#import "NSObject+HQDBDecode.h"
#import "objc/message.h"
#import "HQDBDecodeUtilities.h"
#import "NSObject+YYModel.h"
#import "HQDBHelper.h"


#define force_inline __inline__ __attribute__((always_inline))


static force_inline HQEncodingTypeNSType HQClassGetNSType(Class cls)
{
    if (!cls) return HQEncodingTypeNSUnknown;
    if ([cls isSubclassOfClass:[NSMutableString class]]) return HQEncodingTypeNSMutableString;
    if ([cls isSubclassOfClass:[NSString class]]) return HQEncodingTypeNSString;
    if ([cls isSubclassOfClass:[NSDecimalNumber class]]) return HQEncodingTypeNSDecimalNumber;
    if ([cls isSubclassOfClass:[NSNumber class]]) return HQEncodingTypeNSNumber;
    if ([cls isSubclassOfClass:[NSValue class]]) return HQEncodingTypeNSValue;
    if ([cls isSubclassOfClass:[NSMutableData class]]) return HQEncodingTypeNSMutableData;
    if ([cls isSubclassOfClass:[NSData class]]) return HQEncodingTypeNSData;
    if ([cls isSubclassOfClass:[NSDate class]]) return HQEncodingTypeNSDate;
    if ([cls isSubclassOfClass:[NSURL class]]) return HQEncodingTypeNSURL;
    if ([cls isSubclassOfClass:[NSMutableArray class]]) return HQEncodingTypeNSMutableArray;
    if ([cls isSubclassOfClass:[NSArray class]]) return HQEncodingTypeNSArray;
    if ([cls isSubclassOfClass:[NSMutableDictionary class]]) return HQEncodingTypeNSMutableDictionary;
    if ([cls isSubclassOfClass:[NSDictionary class]]) return HQEncodingTypeNSDictionary;
    if ([cls isSubclassOfClass:[NSMutableSet class]]) return HQEncodingTypeNSMutableSet;
    if ([cls isSubclassOfClass:[NSSet class]]) return HQEncodingTypeNSSet;
    return HQEncodingTypeNSUnknown;
}


@interface _HQClassPropertyInfo : NSObject
{
    @package
    NSString *_name;
    HQEncodingType _type;
    HQEncodingTypeNSType _nsType;
    Class _cls;
    Class _containerCls;
    SEL _setter;
    SEL _getter;
}
@end

@implementation _HQClassPropertyInfo
- (instancetype)initWithProperty:(objc_property_t)property
{
    self = [super init];
    if(self)
    {
        const char *name         = property_getName(property);
        if (name) {
            _name = [NSString stringWithUTF8String:name];
        }
        
        const char *attrs = property_getAttributes(property);
        _type = HQEncodingGetType(attrs);
        
        NSString *typeEncoding = @(attrs);
        NSString *clsName      = nil;
        if(_type == HQEncodingTypeObject)
        {
            NSScanner* scanner            = nil;
            scanner = [NSScanner scannerWithString: typeEncoding];
            if ([scanner scanString:@"T@\"" intoString:NULL])
            {
                [scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"\"<"]
                                        intoString:&clsName];
                if (clsName.length) _cls = objc_getClass(clsName.UTF8String);
                _nsType = HQClassGetNSType(_cls);
            }
        }
        
        if (_name.length)
        {
            _setter = NSSelectorFromString([NSString stringWithFormat:@"set%@%@:", [_name substringToIndex:1].uppercaseString, [_name substringFromIndex:1]]);
            _getter = NSSelectorFromString(_name);
        }

    }
    return self;
}

- (NSString*)description
{
    return [NSString stringWithFormat:@"name %@",_name];
}
@end


static force_inline NSString *MetaGetSqliteType(_HQClassPropertyInfo *info)
{
    switch (info->_type) {
        case HQEncodingTypeBool:
        case HQEncodingTypeInt8:
        case HQEncodingTypeUInt8:
        case HQEncodingTypeInt16:
        case HQEncodingTypeInt32:
        case HQEncodingTypeInt64:
            return @"INTEGER";
        case HQEncodingTypeFloat:
        case HQEncodingTypeDouble:
        case HQEncodingTypeLongDouble:
            return @"REAL";
        case HQEncodingTypeObject:
        {
            switch (info->_nsType)
            {
                case HQEncodingTypeNSDate:
                    return @"DATETIME";
                case HQEncodingTypeNSData:
                    return @"BLOB";
                default:
                    return @"TEXT";
            }
        }
        default:
            return @"TEXT";//默认为文本
    }
    return nil;
}

@interface _HQDBDecodeMeta : NSObject
{
    @package
    NSDictionary *_mapper;
    NSArray *_allPropertyInfos;
    BOOL _hasSqliteTable;
//    NSString *_createSQL;
    NSString *_insertSQL;
    NSString *_delectSQL;
    NSString *_updateSQL;
//    NSString *_className;
}
@end

@implementation _HQDBDecodeMeta
+ (instancetype)metaWithClass:(Class)cls
{
    static CFMutableDictionaryRef cache;
    static dispatch_once_t onceToken;
    static dispatch_semaphore_t lock;
    dispatch_once(&onceToken, ^{
        cache = CFDictionaryCreateMutable(CFAllocatorGetDefault(), 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        lock = dispatch_semaphore_create(1);
    });
    dispatch_semaphore_wait(lock, DISPATCH_TIME_FOREVER);
    _HQDBDecodeMeta *meta = CFDictionaryGetValue(cache, (__bridge const void *)(cls));
    dispatch_semaphore_signal(lock);
    if (!meta) {
        meta = [[_HQDBDecodeMeta alloc] initWithClass:cls];
        if (meta) {
            dispatch_semaphore_wait(lock, DISPATCH_TIME_FOREVER);
            CFDictionarySetValue(cache, (__bridge const void *)(cls), (__bridge const void *)(meta));
            dispatch_semaphore_signal(lock);
            
        }
    }
    return meta;
}


- (instancetype)initWithClass:(Class)cls
{
    if(!cls)return nil;
    
    self = [super init];
    if(self)
    {
        NSSet *ignoredList = nil;
        if ([cls respondsToSelector:@selector(hq_propertyIgnoredList)])
        {
            NSArray *properties = [(id<HQDBDecode>)cls hq_propertyIgnoredList];
            if(properties)
            {
                ignoredList = [NSSet setWithArray:properties];
            }
        }
        
        NSDictionary *genericMapper = nil;
        if ([cls respondsToSelector:@selector(modelContainerPropertyGenericClass)]) {
            genericMapper = [(id<YYModel>)cls modelContainerPropertyGenericClass];
            if (genericMapper) {
                NSMutableDictionary *tmp = [NSMutableDictionary new];
                [genericMapper enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                    if (![key isKindOfClass:[NSString class]]) return;
                    Class meta = object_getClass(obj);
                    if (!meta) return;
                    if (class_isMetaClass(meta)) {
                        tmp[key] = obj;
                    } else if ([obj isKindOfClass:[NSString class]]) {
                        Class cls = NSClassFromString(obj);
                        if (cls) {
                            tmp[key] = cls;
                        }
                    }
                }];
                genericMapper = tmp;
            }
        }

        
        unsigned int count           = 0;
        NSMutableArray *propertyInfo = [NSMutableArray array];
        NSMutableDictionary *mapper  = [NSMutableDictionary new];
        Class superclass = cls;
        do {
            objc_property_t *properties    = class_copyPropertyList(superclass, &count);
            
            for (int i = 0; i < count; i++)
            {

                objc_property_t property      = properties[i];
                _HQClassPropertyInfo *info = [[_HQClassPropertyInfo alloc] initWithProperty:property];
                
                if (ignoredList && [ignoredList containsObject:info->_name]) continue;
                if(info->_type == HQEncodingTypeUnknown || info->_type == HQEncodingTypeVoid) continue;
                
                if(![cls instancesRespondToSelector:info->_setter]) continue;
                if(![cls instancesRespondToSelector:info->_getter]) continue;

                info->_containerCls = genericMapper[info->_name];
                mapper[info->_name] = info;
                [propertyInfo addObject:info];
            }
            free(properties);
            superclass = [superclass superclass];
        } while (![NSStringFromClass(superclass) isEqualToString:@"NSObject"]);
        
        _allPropertyInfos = propertyInfo;
        _mapper = mapper;
        
        //表结构暂时放在这里创建
        [self createTable:cls];
        _insertSQL = [self insertSQL:cls];
        _delectSQL = [self deleteSQL:cls];
        _updateSQL = [self updateSQL:cls];
    }
    return self;
}


- (void)createTable:(Class)cls
{
    //生成create SQL
    NSMutableArray *parameters = [NSMutableArray arrayWithCapacity:_allPropertyInfos.count];
    NSArray *primarykeyList = nil;
    if ([cls respondsToSelector:@selector(hq_propertyPrimarykeyList)])
    {
        NSArray *properties = [(id<HQDBDecode>)cls hq_propertyPrimarykeyList];
        if(properties)
        {
            primarykeyList = [[NSSet setWithArray:properties] allObjects];
        }
    }
    
    for ( _HQClassPropertyInfo *info in _allPropertyInfos)
    {
        [parameters addObject:[NSString stringWithFormat:@"%@ %@",info->_name,MetaGetSqliteType(info)]];
        
    }
    if(primarykeyList.count > 0)
    {
        [parameters addObject:[NSString stringWithFormat:@"PRIMARY KEY (%@)",[primarykeyList componentsJoinedByString:@","]]];
    }
    NSString *sql = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@ (%@)",NSStringFromClass(cls),[parameters componentsJoinedByString:@","]];

    //创建表
    FMDatabaseQueue *queue = [HQDBHelper queueWithClass:cls];
    if(!queue)return;
    
    NSString *className = NSStringFromClass(cls);
    
    [queue inTransaction:^(FMDatabase *db, BOOL *rollback)
     {
         if(![db executeUpdate:sql])return;
         
         _hasSqliteTable = YES;
         
          for (_HQClassPropertyInfo *info in _allPropertyInfos)
          {
              //检测缺失字段
              if(![db columnExists:info->_name inTableWithName:className])
              {
                  NSString *sql = [NSString stringWithFormat:@"ALTER TABLE %@ ADD %@ %@",className,info->_name,MetaGetSqliteType(info)];
                  [db executeUpdate:sql];
              }
          }
     }];
}

//插入sql语句
- (NSString *)insertSQL:(Class)cls
{
    NSMutableArray *valueNames = [NSMutableArray arrayWithCapacity:_allPropertyInfos.count];
    NSMutableArray *propertyNames  = [NSMutableArray arrayWithCapacity:_allPropertyInfos.count];
    for ( _HQClassPropertyInfo *info in _allPropertyInfos)
    {
        [valueNames addObject:[NSString stringWithFormat:@":%@", info->_name]];
        [propertyNames addObject:info->_name];
    }
    NSString *sql;
    sql = [NSString stringWithFormat:@"INSERT OR REPLACE INTO %@ (%@) values (%@)",NSStringFromClass(cls),[propertyNames componentsJoinedByString:@","],[valueNames componentsJoinedByString:@","]];

    return sql;
}

//删除sql语句
- (NSString *)deleteSQL:(Class)cls
{
    NSArray *primarykeyList = nil;
    NSSet *primarykeySet = nil;
    if ([cls respondsToSelector:@selector(hq_propertyPrimarykeyList)])
    {
        NSArray *properties = [(id<HQDBDecode>)cls hq_propertyPrimarykeyList];
        if(properties)
        {
            primarykeySet = [NSSet setWithArray:properties];
            primarykeyList = [primarykeySet allObjects];
        }
    }
    if(primarykeyList.count == 0)return nil;

    
    NSMutableString *sql = [NSMutableString stringWithFormat:@"DELETE FROM %@ WHERE ", NSStringFromClass(cls)];
    [primarykeyList enumerateObjectsUsingBlock:^(NSString *name, NSUInteger idx, BOOL * _Nonnull stop) {
        if(idx == 0)
        {
            [sql appendFormat:@"%@ = :%@ ",name,name];
        }
        else
        {
            [sql appendFormat:@" AND %@ = :%@",name,name];
        }
    }];
    return sql;
}

//删除sql语句
- (NSString *)updateSQL:(Class)cls
{
    NSArray *primarykeyList = nil;
    NSSet *primarykeySet = nil;
    if ([cls respondsToSelector:@selector(hq_propertyPrimarykeyList)])
    {
        NSArray *properties = [(id<HQDBDecode>)cls hq_propertyPrimarykeyList];
        if(properties)
        {
            primarykeySet = [NSSet setWithArray:properties];
            primarykeyList = [primarykeySet allObjects];
        }
    }
    if(primarykeyList.count == 0)return nil;
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(_HQClassPropertyInfo *info, NSDictionary<NSString *,id> * _Nullable bindings) {
        return ![primarykeySet containsObject:info->_name];
    }];
    
    NSArray *allPropertyInfos = [_allPropertyInfos filteredArrayUsingPredicate:predicate];
                              
    NSMutableString *sql = [NSMutableString stringWithFormat:@"UPDATE %@ SET ", NSStringFromClass(cls)];
    [allPropertyInfos enumerateObjectsUsingBlock:^(_HQClassPropertyInfo *info, NSUInteger idx, BOOL * _Nonnull stop) {
        if([primarykeySet containsObject:info->_name])return;
        if(idx == 0)
        {
            [sql appendFormat:@"%@ = :%@ ",info->_name,info->_name];
        }
        else
        {
            [sql appendFormat:@" , %@ = :%@",info->_name,info->_name];
        }
    }];
    
    [sql appendString:@" WHERE "];
    
    [primarykeyList enumerateObjectsUsingBlock:^(NSString *name, NSUInteger idx, BOOL * _Nonnull stop) {
        if(idx == 0)
        {
            [sql appendFormat:@"%@ = :%@ ",name,name];
        }
        else
        {
            [sql appendFormat:@" AND %@ = :%@",name,name];
        }
    }];
    return sql;
}
@end


static force_inline void ModelSetObjectToProperty(__unsafe_unretained id model,
                                                  __unsafe_unretained FMResultSet *rs,
                                                  __unsafe_unretained _HQClassPropertyInfo *info,
                                                  __unsafe_unretained NSString *columnName)
{
    switch (info->_type)
    {
        case HQEncodingTypeVoid:
            break;
        case HQEncodingTypeBool:
        {
            ((void (*)(id, SEL, bool))(void *) objc_msgSend)(model, info->_setter, [rs boolForColumn:columnName]);
        }
            break;
        case HQEncodingTypeInt8:
        {
            ((void (*)(id, SEL, int8_t))(void *) objc_msgSend)(model, info->_setter, (int8_t)[rs intForColumn:columnName]);
        }
            break;
        case HQEncodingTypeUInt8:
        {
            ((void (*)(id, SEL, uint8_t))(void *) objc_msgSend)(model, info->_setter, (uint8_t)[rs intForColumn:columnName]);
        }
            break;
        case HQEncodingTypeInt16:
        {
            ((void (*)(id, SEL, int16_t))(void *) objc_msgSend)(model, info->_setter, (int16_t)[rs intForColumn:columnName]);
        }
            break;
        case HQEncodingTypeUInt16:
        {
            ((void (*)(id, SEL, uint16_t))(void *) objc_msgSend)(model, info->_setter, (uint16_t)[rs intForColumn:columnName]);
        }
            break;
        case HQEncodingTypeInt32:
        {
            ((void (*)(id, SEL, int32_t))(void *) objc_msgSend)(model, info->_setter, (int32_t)[rs intForColumn:columnName]);
        }
            break;
        case HQEncodingTypeUInt32:
        {
            ((void (*)(id, SEL, uint32_t))(void *) objc_msgSend)(model, info->_setter, (uint32_t)[rs intForColumn:columnName]);
        }
            break;
        case HQEncodingTypeInt64:
        {
            ((void (*)(id, SEL, int64_t))(void *) objc_msgSend)(model, info->_setter, (int64_t)[rs longLongIntForColumn:columnName]);
        }
            break;
        case HQEncodingTypeUInt64:
        {
            ((void (*)(id, SEL, uint64_t))(void *) objc_msgSend)(model, info->_setter, (uint64_t)[rs unsignedLongLongIntForColumn:columnName]);
        }
            break;
        case HQEncodingTypeFloat:
        {
            float f = [rs doubleForColumn:columnName];
            if (isnan(f) || isinf(f)) f = 0;
            ((void (*)(id, SEL, float))(void *) objc_msgSend)(model, info->_setter, f);
        }
            break;
        case HQEncodingTypeDouble:
        {
            double d = [rs doubleForColumn:columnName];
            if (isnan(d) || isinf(d)) d = 0;
            ((void (*)(id, SEL, double))(void *) objc_msgSend)(model, info->_setter, d);
        }
            break;
        case HQEncodingTypeLongDouble:
        {
            long double d = [rs doubleForColumn:columnName];
            if (isnan(d) || isinf(d)) d = 0;
            ((void (*)(id, SEL, long double))(void *) objc_msgSend)(model, info->_setter, (long double)d);
        }
            break;
        case HQEncodingTypeObject:
        {
            switch (info->_nsType)
            {
                case HQEncodingTypeNSString:
                case HQEncodingTypeNSMutableString:
                    ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, info->_setter, [rs stringForColumn:columnName]);
                    break;
                case HQEncodingTypeNSDate:
                    ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, info->_setter, [rs dateForColumn:columnName]);
                    break;
                case HQEncodingTypeNSData:
                case HQEncodingTypeNSMutableData:
                    ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, info->_setter, [rs dataForColumn:columnName]);
                    break;
                case HQEncodingTypeNSArray:
                case HQEncodingTypeNSMutableArray:
                {
                    
                    NSString *value = [rs stringForColumn:columnName];
                    if (value)
                    {
                        NSData *data = [value dataUsingEncoding:NSUTF8StringEncoding];
                        NSError *error;
                        id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
                        
                        if (!error)
                        {
                            id obj = json;
                            if(info->_containerCls)
                            {
                                obj = [info->_cls yy_modelArrayWithClass:info->_containerCls json:json];
                            }
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, info->_setter, obj);
                        }
                    }
                }
                    break;
                case HQEncodingTypeNSDictionary:
                case HQEncodingTypeNSMutableDictionary:
                {
                    
                    NSString *value = [rs stringForColumn:columnName];
                    if (value)
                    {
                        NSData *data = [value dataUsingEncoding:NSUTF8StringEncoding];
                        NSError *error;
                        id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
                        
                        if (!error)
                        {
                            id obj = json;
                            if(info->_containerCls)
                            {
                                obj = [info->_cls yy_modelDictionaryWithClass:info->_containerCls json:json];
                            }
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, info->_setter, obj);
                        }
                    }
                }
                    break;
                default:
                {
                    id value = [rs stringForColumn:columnName];
                    if (value)
                    {
                        id obj = [info->_cls yy_modelWithJSON:value];
                        if(obj)
                        {
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, info->_setter, obj);
                        }
                    }
                }
                    break;
            }
        }
            break;
        default:
            break;
    }
}

@implementation NSObject (HQDBDecode)


+ (instancetype)hq_dataWithResultSet:(FMResultSet *)rs
{
    NSObject *obj = [self new];
    _HQDBDecodeMeta *meta = [_HQDBDecodeMeta metaWithClass:self];
    for (int i = 0; i < rs.columnCount; i++)
    {
        NSString *columnName = [rs columnNameForIndex:i];
        _HQClassPropertyInfo *info = meta->_mapper[columnName];
        if(!info) continue;
        //自解析
        ModelSetObjectToProperty(obj,rs,info,columnName);
    }
    return obj;
}



static force_inline id ModelToJSONObject(NSObject *model)
{
    _HQDBDecodeMeta *meta = [_HQDBDecodeMeta metaWithClass:[model class]];
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:meta->_allPropertyInfos.count];
    for (_HQClassPropertyInfo *info in meta->_allPropertyInfos)
    {
        id obj = nil;
        switch (info->_type)
        {
            case HQEncodingTypeBool:
            {
                obj = @(((bool (*)(id, SEL))(void *) objc_msgSend)((id)model, info->_getter));
            }
                break;
            case HQEncodingTypeInt8:
            {
                obj = @(((int8_t (*)(id, SEL))(void *) objc_msgSend)((id)model, info->_getter));
            }
                break;
            case HQEncodingTypeUInt8:
            {
                obj = @(((uint8_t (*)(id, SEL))(void *) objc_msgSend)((id)model, info->_getter));
            }
                break;
            case HQEncodingTypeInt16:
            {
                obj = @(((int16_t (*)(id, SEL))(void *) objc_msgSend)((id)model, info->_getter));
            }
                break;
            case HQEncodingTypeUInt16:
            {
                obj = @(((uint16_t (*)(id, SEL))(void *) objc_msgSend)((id)model, info->_getter));
            }
                break;
            case HQEncodingTypeInt32:
            {
                obj = @(((int32_t (*)(id, SEL))(void *) objc_msgSend)((id)model, info->_getter));
            }
                break;
            case HQEncodingTypeUInt32:
            {
                obj = @(((uint32_t (*)(id, SEL))(void *) objc_msgSend)((id)model, info->_getter));
            }
                break;
            case HQEncodingTypeInt64:
            {
                obj = @(((int64_t (*)(id, SEL))(void *) objc_msgSend)((id)model, info->_getter));
            }
                break;
            case HQEncodingTypeUInt64:
            {
                obj = @(((uint64_t (*)(id, SEL))(void *) objc_msgSend)((id)model, info->_getter));
            }
                break;
            case HQEncodingTypeFloat:
            {
                float num = ((float (*)(id, SEL))(void *) objc_msgSend)((id)model, info->_getter);
                if (isnan(num) || isinf(num)) return nil;
                obj = @(num);
            }
                break;
            case HQEncodingTypeDouble:
            {
                double num = ((double (*)(id, SEL))(void *) objc_msgSend)((id)model, info->_getter);
                if (isnan(num) || isinf(num)) return nil;
                obj = @(num);
            }
                break;
            case HQEncodingTypeLongDouble:
            {
                double num = ((long double (*)(id, SEL))(void *) objc_msgSend)((id)model, info->_getter);
                if (isnan(num) || isinf(num)) return nil;
                obj = @(num);
            }
                break;
            case HQEncodingTypeObject:
            {
                id v = ((id (*)(id, SEL))(void *) objc_msgSend)((id)model, info->_getter);
                switch (info->_nsType)
                {
                    case HQEncodingTypeNSString:
                    case HQEncodingTypeNSMutableString:
                        obj = v;
                        break;
                    case HQEncodingTypeNSDate:
                        obj = v;
                        break;
                    case HQEncodingTypeNSData:
                    case HQEncodingTypeNSMutableData:
                        obj = v;
                        break;
                    default:
                    {
                        obj = [v yy_modelToJSONString];
                    }
                        break;
                }
            }
                break;
            default: obj = nil;break;
        }
        if(obj == nil) obj = [NSNull null];
        [dict setObject:obj forKey:info->_name];
    }
    
    return dict;
}

#pragma mark - 增
/** 单条插入 */
- (BOOL)hq_insert
{
    Class cls = [self class];
    FMDatabaseQueue *queue = [HQDBHelper queueWithClass:cls];
    if(!queue)return nil;
    
    _HQDBDecodeMeta *meta = [_HQDBDecodeMeta metaWithClass:cls];
    if(!meta->_hasSqliteTable)return nil;
    
    __block BOOL success = YES;
    [queue inDatabase:^(FMDatabase *db) {
        success = [db executeUpdate:meta->_insertSQL withParameterDictionary:ModelToJSONObject(self)];
    }];
#ifdef DEBUG
    if(success)
    {}//HQLogInfo(@"%@ 操作成功", NSStringFromClass(cla));
    else
        HQLogError(@"%@  操作失败", NSStringFromClass(cls));
#endif
    return success;
}

+ (BOOL)hq_insertObjects:(nonnull NSArray *)objects
{
    if(objects.count == 0)return YES;
    Class cls = [self class];
    FMDatabaseQueue *queue = [HQDBHelper queueWithClass:cls];
    if(!queue)return nil;
    
    _HQDBDecodeMeta *meta = [_HQDBDecodeMeta metaWithClass:cls];
    if(!meta->_hasSqliteTable)return nil;
    
    __block BOOL success = YES;
    [queue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        for (id obj in objects)
        {
            success = [db executeUpdate:meta->_insertSQL withParameterDictionary:ModelToJSONObject(obj)];
        }
    }];
#ifdef DEBUG
    if(success)
    {}//HQLogInfo(@"%@ 操作成功", NSStringFromClass(cla));
    else
        HQLogError(@"%@  操作失败", NSStringFromClass(cls));
#endif
    return success;
}

#pragma mark - 删
/** 单条删除 */
- (BOOL)hq_delete
{
    Class cls = [self class];
    FMDatabaseQueue *queue = [HQDBHelper queueWithClass:cls];
    if(!queue)return nil;
    
    _HQDBDecodeMeta *meta = [_HQDBDecodeMeta metaWithClass:cls];
    if(!meta->_hasSqliteTable)return nil;
    
    __block BOOL success = YES;
    [queue inDatabase:^(FMDatabase *db) {
        success = [db executeUpdate:meta->_delectSQL withParameterDictionary:ModelToJSONObject(self)];
    }];
#ifdef DEBUG
    if(success)
    {}//HQLogInfo(@"%@ 操作成功", NSStringFromClass(cla));
    else
        HQLogError(@"%@  操作失败", NSStringFromClass(cls));
#endif
    return success;
}

/** 批量删除 */
+ (BOOL)hq_deleteObjects:(nonnull NSArray *)objects
{
    if(objects.count == 0)return YES;
    Class cls = [self class];
    FMDatabaseQueue *queue = [HQDBHelper queueWithClass:cls];
    if(!queue)return nil;
    
    _HQDBDecodeMeta *meta = [_HQDBDecodeMeta metaWithClass:cls];
    if(!meta->_hasSqliteTable)return nil;
    
    __block BOOL success = YES;
    [queue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        for (id obj in objects)
        {
            success = [db executeUpdate:meta->_delectSQL withParameterDictionary:ModelToJSONObject(obj)];
        }
    }];
#ifdef DEBUG
    if(success)
    {}//HQLogInfo(@"%@ 操作成功", NSStringFromClass(cla));
    else
        HQLogError(@"%@  操作失败", NSStringFromClass(cls));
#endif
    return success;
}

/** 清空表的所有数据 */
+ (BOOL)hq_clearTable
{
    Class cls = [self class];
    FMDatabaseQueue *queue = [HQDBHelper queueWithClass:cls];
    if(!queue)return nil;
    
    _HQDBDecodeMeta *meta = [_HQDBDecodeMeta metaWithClass:cls];
    if(!meta->_hasSqliteTable)return nil;
    
    __block BOOL success = YES;
    [queue inDatabase:^(FMDatabase *db) {
        success = [db executeUpdate:[NSString stringWithFormat:@"DELETE FROM %@ ",NSStringFromClass(cls)]];
    }];
#ifdef DEBUG
    if(success)
    {}//HQLogInfo(@"%@ 操作成功", NSStringFromClass(cla));
    else
        NSLog(@"%@  操作失败", NSStringFromClass(cls));
#endif
    return success;
}

/** 通过对应列删除
 *  例子:根据userno为002的用户数据  [User hq_deleteByColumns:@{@"userno":@"002"}]
 */
+ (BOOL)hq_deleteByColumns:(nonnull NSDictionary *)columns
{
    Class cls = [self class];
    FMDatabaseQueue *queue = [HQDBHelper queueWithClass:cls];
    if(!queue)return nil;
    
    _HQDBDecodeMeta *meta = [_HQDBDecodeMeta metaWithClass:cls];
    if(!meta->_hasSqliteTable)return nil;
    
    __block BOOL success = YES;
    [queue inDatabase:^(FMDatabase *db) {
        NSMutableString *where = [NSMutableString string];
        NSArray *allKeys = [columns allKeys];
        for (int i = 0; i< allKeys.count; i++)
        {
            NSString *key = allKeys[i];
            if( i == allKeys.count -1 )
            {
                [where appendFormat:@" %@ = :%@",key,key];
            }
            else
            {
                [where appendFormat:@" %@ = :%@ AND",key,key];
            }
        }
        if(where.length)
        {
            success = [db executeUpdate:[NSString stringWithFormat:@"DELETE FROM %@ WHERE %@",NSStringFromClass(cls),where] withParameterDictionary:columns];
        }
        else
        {
            success = [db executeUpdate:[NSString stringWithFormat:@"DELETE FROM %@",NSStringFromClass(cls)]];
        }
    }];
#ifdef DEBUG
    if(success)
    {}//HQLogInfo(@"%@ 操作成功", NSStringFromClass(cla));
    else
        NSLog(@"%@  操作失败", NSStringFromClass(cls));
#endif
    return success;
}

+ (BOOL)hq_deleteByWHERE:(nonnull NSString *)sql withDictionary:(nullable NSDictionary *)map
{
    Class cls = [self class];
    FMDatabaseQueue *queue = [HQDBHelper queueWithClass:cls];
    if(!queue)return nil;
    
    _HQDBDecodeMeta *meta = [_HQDBDecodeMeta metaWithClass:cls];
    if(!meta->_hasSqliteTable)return nil;
    
    __block BOOL success = YES;
    [queue inDatabase:^(FMDatabase *db) {
        success = [db executeUpdate:[NSString stringWithFormat:@"DELETE FROM %@ WHERE %@",NSStringFromClass(cls),sql] withParameterDictionary:map];
    }];
#ifdef DEBUG
    if(success)
    {}//HQLogInfo(@"%@ 操作成功", NSStringFromClass(cla));
    else
        NSLog(@"%@  操作失败", NSStringFromClass(cls));
#endif
    return success;
}

///** 指定完整sql, map同上 */
//+ (BOOL)hq_deleteBySQL:(nonnull NSString *)sql withDictionary:(nullable NSDictionary *)map
//{
//    Class cls = [self class];
//    FMDatabaseQueue *queue = [HQDBHelper queueWithClass:cls];
//    if(!queue)return nil;
//    
//    _HQDBDecodeMeta *meta = [_HQDBDecodeMeta metaWithClass:cls];
//    if(!meta->_hasSqliteTable)return nil;
//    
//    __block BOOL success = YES;
//    [queue inDatabase:^(FMDatabase *db) {
//        success = [db executeUpdate:sql withParameterDictionary:map];
//    }];
//#ifdef DEBUG
//    if(success)
//    {}//HQLogInfo(@"%@ 操作成功", NSStringFromClass(cla));
//    else
//        NSLog(@"%@  操作失败", NSStringFromClass(cls));
//#endif
//    return success;
//}

#pragma mark - 改
/** 单条修改  !该方法无法修改主键*/
- (BOOL)hq_update
{
    Class cls = [self class];
    FMDatabaseQueue *queue = [HQDBHelper queueWithClass:cls];
    if(!queue)return nil;
    
    _HQDBDecodeMeta *meta = [_HQDBDecodeMeta metaWithClass:cls];
    if(!meta->_hasSqliteTable)return nil;
    
    __block BOOL success = YES;
    [queue inDatabase:^(FMDatabase *db) {
        success = [db executeUpdate:meta->_updateSQL withParameterDictionary:ModelToJSONObject(self)];
    }];
#ifdef DEBUG
    if(success)
    {}//HQLogInfo(@"%@ 操作成功", NSStringFromClass(cla));
    else
        HQLogError(@"%@  操作失败", NSStringFromClass(cls));
#endif
    return success;
}

/** 批量插入 */
+ (BOOL)hq_updateObjects:(nonnull NSArray *)objects
{
    if(objects.count == 0)return YES;
    Class cls = [self class];
    FMDatabaseQueue *queue = [HQDBHelper queueWithClass:cls];
    if(!queue)return nil;
    
    _HQDBDecodeMeta *meta = [_HQDBDecodeMeta metaWithClass:cls];
    if(!meta->_hasSqliteTable)return nil;
    
    __block BOOL success = YES;
    [queue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        for (id obj in objects)
        {
            success = [db executeUpdate:meta->_updateSQL withParameterDictionary:ModelToJSONObject(obj)];
        }
    }];
#ifdef DEBUG
    if(success)
    {}//HQLogInfo(@"%@ 操作成功", NSStringFromClass(cla));
    else
        HQLogError(@"%@  操作失败", NSStringFromClass(cls));
#endif
    return success;
}

/** 通过列所对应的值修改map内对应的内容 例子columns @{userno:@"001"} map @{@"nickname":@"哈哈2"}*/
+ (BOOL)hq_updateByColumns:(nonnull NSDictionary *)columns withDictionary:(nullable NSDictionary *)map
{
    Class cls = [self class];
    FMDatabaseQueue *queue = [HQDBHelper queueWithClass:cls];
    if(!queue)return nil;
    
    _HQDBDecodeMeta *meta = [_HQDBDecodeMeta metaWithClass:cls];
    if(!meta->_hasSqliteTable)return nil;
    
    __block BOOL success = YES;
    [queue inDatabase:^(FMDatabase *db) {
        
        NSMutableString *where = [NSMutableString string];
        NSMutableString *set = [NSMutableString string];
        NSArray *allKeys = [map allKeys];
        
        for ( int i=0; i<allKeys.count; i++)
        {
            NSString *key = allKeys[i];
            if(i == allKeys.count -1)
            {
                [set appendFormat:@" %@ = :%@",key,key];
            }
            else
            {
                [set appendFormat:@" %@ = :%@,",key,key];
            }
        }
        
        allKeys = [columns allKeys];
        
        for ( int i=0; i<allKeys.count; i++)
        {
            NSString *key = allKeys[i];
            if(i == allKeys.count-1 )
            {
                [where appendFormat:@" %@ = :%@",key,key];
            }
            else
            {
                [where appendFormat:@" %@ = :%@ AND",key,key];
            }
        }
        
        if(set.length == 0)
        {
            success = NO;
            return;
        }
        
        if(where.length)
        {
            NSMutableDictionary *maps = [NSMutableDictionary dictionaryWithDictionary:map];
            [maps addEntriesFromDictionary:columns];
            success = [db executeUpdate:[NSString stringWithFormat:@"UPDATE %@ SET %@ WHERE %@",NSStringFromClass(cls),set,where] withParameterDictionary:maps];
        }
        else
        {
            success = [db executeUpdate:[NSString stringWithFormat:@"UPDATE %@ SET %@",NSStringFromClass(cls),set]];
        }
        
    }];
#ifdef DEBUG
    if(success)
    {}//HQLogInfo(@"%@ 操作成功", NSStringFromClass(cla));
    else
        NSLog(@"%@  操作失败", NSStringFromClass(cls));
#endif
    return success;
}

///** 指定完整sql, map同上 */
+ (BOOL)hq_updateBySQL:(nonnull NSString *)sql withDictionary:(nullable NSDictionary *)map
{
    Class cls = [self class];
    FMDatabaseQueue *queue = [HQDBHelper queueWithClass:cls];
    if(!queue)return nil;
    
    _HQDBDecodeMeta *meta = [_HQDBDecodeMeta metaWithClass:cls];
    if(!meta->_hasSqliteTable)return nil;
    
    __block BOOL success = YES;
    [queue inDatabase:^(FMDatabase *db) {
        success = [db executeUpdate:sql withParameterDictionary:map];
    }];
#ifdef DEBUG
    if(success)
    {}//HQLogInfo(@"%@ 操作成功", NSStringFromClass(cla));
    else
        NSLog(@"%@  操作失败", NSStringFromClass(cls));
#endif
    return success;
}

#pragma mark - 查
+ (nullable NSArray *)hq_all
{
    Class cls = [self class];
    NSMutableArray *result = [NSMutableArray array];
    FMDatabaseQueue *queue = [HQDBHelper queueWithClass:cls];
    if(!queue)return nil;
    
    _HQDBDecodeMeta *meta = [_HQDBDecodeMeta metaWithClass:cls];
    if(!meta->_hasSqliteTable)return nil;
    
    __block BOOL success = YES;
    [queue inDatabase:^(FMDatabase *db) {
        
        FMResultSet *rs = [db executeQuery:[NSString stringWithFormat:@"SELECT * FROM %@",NSStringFromClass(cls)]];
        while ([rs next])
        {
            [result addObject:[cls hq_dataWithResultSet:rs]];
        }
        [rs close];
    }];
#ifdef DEBUG
    if(success)
    {}//HQLogInfo(@"%@ 操作成功", NSStringFromClass(cla));
    else
        HQLogError(@"%@  操作失败", NSStringFromClass(cls));
#endif
    return result;
}

//** 指定行查询  例 columns @{@"state" : @(1)} */
+ (nullable NSArray *)hq_selectByColumns:(nullable NSDictionary *)columns
{
    Class cls = [self class];
    NSMutableArray *result = [NSMutableArray array];
    FMDatabaseQueue *queue = [HQDBHelper queueWithClass:cls];
    if(!queue)return nil;
    
    _HQDBDecodeMeta *meta = [_HQDBDecodeMeta metaWithClass:cls];
    if(!meta->_hasSqliteTable)return nil;
    
    __block BOOL success = YES;
    [queue inDatabase:^(FMDatabase *db) {
        NSMutableString *where = [NSMutableString string];
        NSArray *allKeys = [columns allKeys];
        for (int i = 0; i< allKeys.count; i++)
        {
            NSString *key = allKeys[i];
            if( i == allKeys.count -1 )
            {
                [where appendFormat:@" %@ = :%@",key,key];
            }
            else
            {
                [where appendFormat:@" %@ = :%@ AND",key,key];
            }
        }
        
        FMResultSet *rs;
        if(where.length)
        {
            rs = [db executeQuery:[NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@",NSStringFromClass(cls),where] withParameterDictionary:columns];
        }
        else
        {
            rs = [db executeQuery:[NSString stringWithFormat:@"SELECT * FROM %@",NSStringFromClass(cls)]];
        }
        
        while ([rs next])
        {
            [result addObject:[cls hq_dataWithResultSet:rs]];
        }
    }];
#ifdef DEBUG
    if(success)
    {}//HQLogInfo(@"%@ 操作成功", NSStringFromClass(cla));
    else
        HQLogError(@"%@  操作失败", NSStringFromClass(cls));
#endif
    return result;
}

//** 指定条件查询 例 sql @"language = :language ORDER BY updateTime DESC LIMIT 10" map: @{@"language":@"zh"} */
+ (nullable NSArray *)hq_selectByWHERE:(nullable NSString *)sql withDictionary:(nullable NSDictionary *)map
{
    Class cls = [self class];
    NSMutableArray *result = [NSMutableArray array];
    FMDatabaseQueue *queue = [HQDBHelper queueWithClass:cls];
    if(!queue)return nil;
    
    _HQDBDecodeMeta *meta = [_HQDBDecodeMeta metaWithClass:cls];
    if(!meta->_hasSqliteTable)return nil;
    
    __block BOOL success = YES;
    [queue inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:[NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@",NSStringFromClass(cls),sql] withParameterDictionary:map];
        while ([rs next])
        {
            [result addObject:[cls hq_dataWithResultSet:rs]];
        }
        [rs close];
    }];
#ifdef DEBUG
    if(success)
    {}//HQLogInfo(@"%@ 操作成功", NSStringFromClass(cla));
    else
        HQLogError(@"%@  操作失败", NSStringFromClass(cls));
#endif
    return result;
}

///** 指定完整sql, map同上 */
+ (nullable NSArray *)hq_selectBySQL:(nullable NSString *)sql withDictionary:(nullable NSDictionary *)map
{
    Class cls = [self class];
    NSMutableArray *result = [NSMutableArray array];
    FMDatabaseQueue *queue = [HQDBHelper queueWithClass:cls];
    if(!queue)return nil;
    
    _HQDBDecodeMeta *meta = [_HQDBDecodeMeta metaWithClass:cls];
    if(!meta->_hasSqliteTable)return nil;
    
    __block BOOL success = YES;
    [queue inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:sql withParameterDictionary:map];
        while ([rs next])
        {
            [result addObject:[cls hq_dataWithResultSet:rs]];
        }
        [rs close];
    }];
#ifdef DEBUG
    if(success)
    {}//HQLogInfo(@"%@ 操作成功", NSStringFromClass(cla));
    else
        HQLogError(@"%@  操作失败", NSStringFromClass(cls));
#endif
    return result;
}
@end































