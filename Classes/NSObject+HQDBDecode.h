//
//  NSObject+HQDBDecode.h
//  HQModelDemo
//
//  Created by 刘欢庆 on 2017/4/11.
//  Copyright © 2017年 刘欢庆. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <FMDB/FMDB.h>

@interface NSObject (HQDBDecode)
//+ (nullable instancetype)hq_dataWithResultSet:(nullable FMResultSet *)rs;

#pragma mark - 增
/** 单条插入 */
- (BOOL)hq_insert;

/** 批量插入 */
+ (BOOL)hq_insertObjects:(nonnull NSArray *)objects;

#pragma mark - 删
/** 单条删除 */
- (BOOL)hq_delete;

/** 批量删除 */
+ (BOOL)hq_deleteObjects:(nonnull NSArray *)objects;

/** 清空表的所有数据 */
+ (BOOL)hq_clearTable;

/** 通过对应列删除
 *  例:根据userno为002的用户数据  [User hq_deleteByColumns:@{@"userno":@"002"}]
 */
+ (BOOL)hq_deleteByColumns:(nonnull NSDictionary *)columns;

/** 指定WHERE条件删除 例: sql @"userno = :no", map @{@"no":@"003"}*/
+ (BOOL)hq_deleteByWHERE:(nonnull NSString *)sql withDictionary:(nullable NSDictionary *)map;

/** 指定完整sql, map同上 */
//+ (BOOL)hq_deleteBySQL:(nonnull NSString *)sql withDictionary:(nullable NSDictionary *)map;

#pragma mark - 改
/** 单条修改 */
- (BOOL)hq_update;

/** 批量插入 */
+ (BOOL)hq_updateObjects:(nonnull NSArray *)objects;

/** 通过列所对应的值修改map内对应的内容 例子columns @{userno:@"001"} map @{@"nickname":@"哈哈2"}*/
+ (BOOL)hq_updateByColumns:(nonnull NSDictionary *)columns withDictionary:(nullable NSDictionary *)map;

/** 指定完整sql, map同上 */
+ (BOOL)hq_updateBySQL:(nonnull NSString *)sql withDictionary:(nullable NSDictionary *)map;

#pragma mark - 查
/** 查询所有数据 */
+ (nullable NSArray *)hq_all;

/** 指定行查询  例 columns @{@"state" : @(1)} */
+ (nullable NSArray *)hq_selectByColumns:(nullable NSDictionary *)columns;

/** 指定条件查询 例 sql @"language = :language ORDER BY updateTime DESC LIMIT 10" map: @{@"language":@"zh"} */
+ (nullable NSArray *)hq_selectByWHERE:(nullable NSString *)sql withDictionary:(nullable NSDictionary *)map;

/** 指定完整sql, map同上 */
+ (nullable NSArray *)hq_selectBySQL:(nullable NSString *)sql withDictionary:(nullable NSDictionary *)map;

@end



#pragma mark - 自定义协议
@protocol HQDBDecode <NSObject>
@optional
/** 忽略字段列表*/
+ (nullable NSArray<NSString *> *)hq_propertyIgnoredList;

/** 主键列表 */
+ (nullable NSArray<NSString *> *)hq_propertyPrimarykeyList;

/** 所属库名称 该字段是生成数据库的必要字段*/
+ (nonnull NSString *)hq_dbName;

//返回容器类中的所需要存放的数据类型 (以 Class 或 Class Name 的形式)。modelContainerPropertyGenericClass
//modelContainerPropertyGenericClass
//此方法为YYModel中的的容器类对应表
@end
