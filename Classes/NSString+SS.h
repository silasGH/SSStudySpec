//
//  NSString+SS.h
//  Study
//
//  Created by silas on 11/14/19.
//  Copyright © 2019 GK. All rights reserved.
//
#if !TARGET_OS_IOS
#import <AppKit/AppKit.h>
#endif

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSString (SS)

+ (BOOL (^)(__kindof NSString *__nullable))isEmpty;

@end

NS_ASSUME_NONNULL_END
