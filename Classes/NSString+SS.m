//
//  NSString+SS.m
//  Study
//
//  Created by silas on 11/14/19.
//  Copyright © 2019 GK. All rights reserved.
//
#import <TargetConditionals.h>
#if !TARGET_OS_IOS
#import <AppKit/AppKit.h>
#endif
#import "NSString+SS.h"

@implementation NSString (SS)

+ (BOOL (^)(__kindof NSString *__nullable))isEmpty {
    return ^BOOL(NSString *str) {
        if ([str isEqual:[NSNull null]]
            || str == nil
            || str == NULL
            || [str isEqualToString:@""]) {
            return YES;
        }
        return NO;
    };
}

@end
