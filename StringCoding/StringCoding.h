//
//  StringCoding.h
//
//  Version 1.2.2
//
//  Created by Nick Lockwood on 05/02/2012.
//  Copyright (c) 2012 Charcoal Design
//
//  Distributed under the permissive zlib License
//  Get the latest version from here:
//
//  https://github.com/nicklockwood/StringCoding
//
//  This software is provided 'as-is', without any express or implied
//  warranty.  In no event will the authors be held liable for any damages
//  arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,
//  including commercial applications, and to alter it and redistribute it
//  freely, subject to the following restrictions:
//
//  1. The origin of this software must not be misrepresented; you must not
//  claim that you wrote the original software. If you use this software
//  in a product, an acknowledgment in the product documentation would be
//  appreciated but is not required.
//
//  2. Altered source versions must be plainly marked as such, and must not be
//  misrepresented as being the original software.
//
//  3. This notice may not be removed or altered from any source distribution.
//

#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <TargetConditionals.h>
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif


#ifndef SC_SWIZZLE_ENABLED
#define SC_SWIZZLE_ENABLED 1
#endif


extern NSString *const StringCodingErrorDomain;


@interface NSObject (StringCoding)

- (void)setValueWithString:(NSString *)value forKey:(NSString *)key;
- (void)setValueWithString:(NSString *)value forKeyPath:(NSString *)keyPath;

@end


@class UIColor, UIImage, UIFont;
@class NSColor, NSImage, NSFont;


@interface NSString (StringCoding)

- (BOOL)isNumeric;

- (Class)classValue;
- (SEL)selectorValue;
- (char)charValue;
- (NSURL *)NSURLValue;
- (NSURLRequest *)NSURLRequestValue;
- (NSNumber *)NSNumberValue;

- (CGPoint)CGPointValue;
- (CGSize)CGSizeValue;
- (CGRect)CGRectValue;

- (CGColorRef)CGColorValue;
- (CGImageRef)CGImageValue;
- (CGFontRef)CGFontValue;

- (NSTextAlignment)NSTextAlignmentValue;
- (NSLineBreakMode)NSLineBreakModeValue;

#if TARGET_OS_IPHONE

- (UIColor *)UIColorValue;
- (UIImage *)UIImageValue;
- (UIFont *)UIFontValue;

- (UIEdgeInsets)UIEdgeInsetsValue;
- (UIOffset)UIOffsetValue;
- (UIViewContentMode)UIViewContentModeValue;
- (UIViewAutoresizing)UIViewAutoresizingValue;
- (UIBaselineAdjustment)UIBaselineAdjustment;

- (UIControlState)UIControlStateValue;
- (UIControlEvents)UIControlEventsValue;

- (UITextBorderStyle)UITextBorderStyleValue;
- (UITextFieldViewMode)UITextFieldViewModeValue;
- (UIDataDetectorTypes)UIDataDetectorTypesValue;

- (UIScrollViewIndicatorStyle)UIScrollViewIndicatorStyleValue;

- (UITableViewStyle)UITableViewStyleValue;
- (UITableViewScrollPosition)UITableViewScrollPositionValue;
- (UITableViewRowAnimation)UITableViewRowAnimationValue;
- (UITableViewCellStyle)UITableViewCellStyleValue;
- (UITableViewCellSeparatorStyle)UITableViewCellSeparatorStyleValue;
- (UITableViewCellSelectionStyle)UITableViewCellSelectionStyleValue;
- (UITableViewCellEditingStyle)UITableViewCellEditingStyleValue;
- (UITableViewCellAccessoryType)UITableViewCellAccessoryTypeValue;
- (UITableViewCellStateMask)UITableViewCellStateMaskValue;

- (UIButtonType)UIButtonTypeValue;

- (UIBarStyle)UIBarStyleValue;
- (UIBarMetrics)UIBarMetricsValue;
- (UIBarButtonItemStyle)UIBarButtonItemStyleValue;
- (UIBarButtonSystemItem)UIBarButtonSystemItemValue;
- (UITabBarSystemItem)UITabBarSystemItemValue;

#else

- (NSPoint)NSPointValue;
- (NSSize)NSSizeValue;
- (NSRect)NSRectValue;
- (NSColor *)NSColorValue;
- (NSImage *)NSImageValue;
- (NSFont *)NSFontValue;

#endif

@end

