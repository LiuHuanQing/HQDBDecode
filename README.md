# HQDBDecode

我觉得这个种写法还是不够'聪明'  

敬请期待2.0版 的语法:

```objc
obj.field(*).where({id:001}).select();
```
> 刚从内网gitlab转过来,没上pod,很多东西暂时没有

具体用法注释其实已经写的很清楚:
```objc
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

```
