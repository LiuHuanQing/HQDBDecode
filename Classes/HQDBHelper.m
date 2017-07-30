//
//  HQDBHelper.m
//  HQModelDemo
//
//  Created by 刘欢庆 on 2017/4/12.
//  Copyright © 2017年 刘欢庆. All rights reserved.
//

#import "HQDBHelper.h"
#import "NSObject+HQDBDecode.h"
@interface HQDBHelper()
@property (nonatomic,strong) NSMutableDictionary *dbQueues;
@end

@implementation HQDBHelper
+ (instancetype)sharedInstance
{
    static HQDBHelper *_sharedInstance;
    static dispatch_once_t _onceToken;
    dispatch_once(&_onceToken, ^{
        _sharedInstance = [[self alloc] init];
    });
    return _sharedInstance;
}

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _dbQueues = [NSMutableDictionary dictionary];
    }
    return self;
}


- (FMDatabaseQueue *)queueWithClass:(Class)cls
{
    if (![cls respondsToSelector:@selector(hq_dbName)])
    {
        HQLogError(@"%@:hq_dbName未实现,找不到所属库",NSStringFromClass(cls));
        return nil;
    }
    
    NSString *dbName = [(id<HQDBDecode>)cls hq_dbName];
    if(dbName == (id)kCFNull || dbName.length == 0)
    {
        HQLogError(@"%@:hq_dbName为空,找不到所属库",NSStringFromClass(cls));
        return nil;
    }

    @synchronized(self){
        //创建库
        FMDatabaseQueue *dbQueue = [self.dbQueues objectForKey:dbName];
        if(!dbQueue)
        {
            NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
            NSString *docPath = [paths firstObject];
            dbQueue = [FMDatabaseQueue databaseQueueWithPath:[docPath stringByAppendingPathComponent:dbName]];
            if(!dbQueue)
            {
                HQLogError(@"%@:FMDatabaseQueue 创建失败",NSStringFromClass(cls));
                return nil;
            }
            
            [self.dbQueues setObject:dbQueue forKey:dbName];
        }
        return dbQueue;
    };
}

+ (FMDatabaseQueue *)queueWithClass:(Class)cls
{
    return [[HQDBHelper sharedInstance] queueWithClass:cls];
}

@end
