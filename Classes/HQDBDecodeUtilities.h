//
//  HQDBDecodeUtilities.h
//  HQModelDemo
//
//  Created by 刘欢庆 on 2017/4/11.
//  Copyright © 2017年 刘欢庆. All rights reserved.
//

#import <Foundation/Foundation.h>


typedef NS_ENUM(NSUInteger, HQEncodingType) {
    HQEncodingTypeUnknown    = 0, ///< unknown
    HQEncodingTypeVoid       = 1, ///< void
    HQEncodingTypeBool       = 2, ///< bool
    HQEncodingTypeInt8       = 3, ///< char / BOOL
    HQEncodingTypeUInt8      = 4, ///< unsigned char
    HQEncodingTypeInt16      = 5, ///< short
    HQEncodingTypeUInt16     = 6, ///< unsigned short
    HQEncodingTypeInt32      = 7, ///< int
    HQEncodingTypeUInt32     = 8, ///< unsigned int
    HQEncodingTypeInt64      = 9, ///< long long
    HQEncodingTypeUInt64     = 10, ///< unsigned long long
    HQEncodingTypeFloat      = 11, ///< float
    HQEncodingTypeDouble     = 12, ///< double
    HQEncodingTypeLongDouble = 13, ///< long double
    HQEncodingTypeObject     = 14, ///< id
//    HQEncodingTypeClass      = 15, ///< Class
//    HQEncodingTypeSEL        = 16, ///< SEL
//    HQEncodingTypeBlock      = 17, ///< block
//    HQEncodingTypePointer    = 18, ///< void*
//    HQEncodingTypeStruct     = 19, ///< struct
//    HQEncodingTypeUnion      = 20, ///< union
//    HQEncodingTypeCString    = 21, ///< char*
//    HQEncodingTypeCArray     = 22, ///< char[10] (for example)

    
    
};

typedef NS_ENUM(NSUInteger, HQEncodingTypeNSType)
{
    HQEncodingTypeNSUnknown = 0,
    HQEncodingTypeNSString,
    HQEncodingTypeNSMutableString,
    HQEncodingTypeNSValue,
    HQEncodingTypeNSNumber,
    HQEncodingTypeNSDecimalNumber,
    HQEncodingTypeNSData,
    HQEncodingTypeNSMutableData,
    HQEncodingTypeNSDate,
    HQEncodingTypeNSURL,
    HQEncodingTypeNSArray,
    HQEncodingTypeNSMutableArray,
    HQEncodingTypeNSDictionary,
    HQEncodingTypeNSMutableDictionary,
    HQEncodingTypeNSSet,
    HQEncodingTypeNSMutableSet,
};
@interface HQDBDecodeUtilities : NSObject
HQEncodingType HQEncodingGetType(const char *typeEncoding);
@end
