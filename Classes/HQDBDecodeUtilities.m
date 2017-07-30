//
//  HQDBDecodeUtilities.m
//  HQModelDemo
//
//  Created by 刘欢庆 on 2017/4/11.
//  Copyright © 2017年 刘欢庆. All rights reserved.
//

#import "HQDBDecodeUtilities.h"

@implementation HQDBDecodeUtilities
HQEncodingType HQEncodingGetType(const char *typeEncoding)
{
    char *type = (char *)typeEncoding;
    if (!type) return HQEncodingTypeUnknown;
    size_t len = strlen(type);
    if (len < 3) return HQEncodingTypeUnknown;//最少三个字节(T@?)

    switch (type[1])
    {
        case 'v': return HQEncodingTypeVoid;
        case 'B': return HQEncodingTypeBool;
        case 'c': return HQEncodingTypeInt8;
        case 'C': return HQEncodingTypeUInt8;
        case 's': return HQEncodingTypeInt16;
        case 'S': return HQEncodingTypeUInt16;
        case 'i': return HQEncodingTypeInt32;
        case 'I': return HQEncodingTypeUInt32;
        case 'l': return HQEncodingTypeInt32;
        case 'L': return HQEncodingTypeUInt32;
        case 'q': return HQEncodingTypeInt64;
        case 'Q': return HQEncodingTypeUInt64;
        case 'f': return HQEncodingTypeFloat;
        case 'd': return HQEncodingTypeDouble;
        case 'D': return HQEncodingTypeLongDouble;
//        case '#': return HQEncodingTypeClass;
//        case ':': return HQEncodingTypeSEL;
//        case '*': return HQEncodingTypeCString;
//        case '^': return HQEncodingTypePointer;
//        case '[': return HQEncodingTypeCArray;
//        case '(': return HQEncodingTypeUnion;
//        case '{': return HQEncodingTypeStruct;
        case '@':
        {
            if (type[2] == '?')
                return HQEncodingTypeUnknown;
            else
                return HQEncodingTypeObject;
        }
        default: return HQEncodingTypeUnknown;
    }
}


@end
