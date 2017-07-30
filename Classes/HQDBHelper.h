//
//  HQDBHelper.h
//  HQModelDemo
//
//  Created by 刘欢庆 on 2017/4/12.
//  Copyright © 2017年 刘欢庆. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <FMDB/FMDB.h>
#if DEBUG
#define HQLogError(frmt, ...) NSLog(@"❌[%@:%@ %d]  %@ \n", \
[[NSString stringWithUTF8String:__FILE__] lastPathComponent],   \
NSStringFromSelector(_cmd), \
__LINE__,   \
[NSString stringWithFormat:(frmt), ##__VA_ARGS__])

#define HQLogInfo(frmt, ...) NSLog(@"✅[%@:%@ %d]  %@ \n", \
[[NSString stringWithUTF8String:__FILE__] lastPathComponent],   \
NSStringFromSelector(_cmd), \
__LINE__,   \
[NSString stringWithFormat:(frmt), ##__VA_ARGS__])

#else

#define HQLogError(frmt, ...)
#define HQLogInfo(frmt, ...)
#endif

@interface HQDBHelper : NSObject
+ (FMDatabaseQueue *)queueWithClass:(Class)cls;
@end
