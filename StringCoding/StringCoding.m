//
//  StringCoding.m
//
//  Version 1.0
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

#import "StringCoding.h"
#import <objc/message.h>


NSString *const StringCodingErrorDomain = @"StringCodingErrorDomain";


@interface NSString (StringCoding_Private)

- (id)valueForType:(NSString *)type;

@end


@implementation NSObject (StringCoding)

- (NSString *)SC_propertyTypeForKey:(NSString *)key
{
    //create cache
    static NSMutableDictionary *cacheByClass = nil;
    if (cacheByClass == nil)
    {
        cacheByClass = [[NSMutableDictionary alloc] init];
    }
    NSString *className = NSStringFromClass([self class]);
    NSCache *cache = cacheByClass[className];
    if (cache == nil)
    {
        cache = [[NSCache alloc] init];
        cacheByClass[className] = cache;
    }
    
    //check cache
    NSString *type = [cache objectForKey:key];
    if (type) return [type length]? type: nil;
    
    //get selector for setter method
    SEL setter = NSSelectorFromString([@"set" stringByAppendingFormat:@"%@%@:",
                                       [[key substringToIndex:1] uppercaseString],
                                       [key substringFromIndex:1]]);
    
    BOOL isPointer = NO;
    if ([self respondsToSelector:setter])
    {
        Class class = [self class];
        while (class != [NSObject class])
        {
            //get the first method argument
            Method method = class_getInstanceMethod([self class], setter);
            char *arg = method_copyArgumentType(method, 2);
            NSString *typeName = @(arg);
            free(arg);
            
            //handle pointers
            if ([typeName hasPrefix:@"^"])
            {
                isPointer = YES;
                typeName = [typeName substringFromIndex:1];
            }
            
            if ([typeName isEqualToString:@"@"])
            {
                //object of unknown type, get value from property keys
                unsigned int count;
                objc_property_t *properties = class_copyPropertyList(class, &count);
                for (int i = 0; i < count; i++)
                {
                    objc_property_t property = properties[i];
                    const char *name = property_getName(property);
                    if ([key isEqualToString:@(name)])
                    {
                        //get type
                        const char *attributes = property_getAttributes(property);
                        typeName = @(attributes);
                        typeName = [typeName substringFromIndex:3];
                        NSRange range = [typeName rangeOfString:@"\""];
                        if (range.location != NSNotFound)
                        {
                            type = [typeName substringToIndex:range.location];
                        }
                        break;
                    }
                }
                free(properties);
            }
            else if ([typeName hasPrefix:@"{"])
            {
                //struct
                typeName = [typeName substringFromIndex:1];
                NSRange range = [typeName rangeOfString:@"="];
                if (range.location != NSNotFound)
                {
                    type = [typeName substringToIndex:range.location];
                }
            }
            else
            {
                static NSDictionary *typeMap = nil;
                if (typeMap == nil)
                {
                    typeMap = @{@"c": @"char",
                                @"i": @"int",
                                @"s": @"short",
                                @"l": @"long",
                                @"f": @"float"};
                }
                type = typeMap[typeName];
            }
            
            if (type)
            {
                break;
            }
            else
            {
                //try superclass instead
                class = [class superclass];
            }
        }
    }
    
    if (!type)
    {
        //failed to get type any other way, so try getting existing value
        if ([self respondsToSelector:NSSelectorFromString(key)])
        {
            id value = [self valueForKey:key];
            if (value)
            {
                type = NSStringFromClass([value class]);
            }
        }
    }
    
    //handle pointers
    if (isPointer)
    {
        type = [type stringByAppendingString:@"Ref"];
    }
    
    //cache and return type
    [cache setObject:type ?: @"" forKey:key];
    return type;
}

- (void)setStringValue:(NSString *)stringValue forKey:(NSString *)key
{
    if ([key length])
    {
        SEL stringSetter = NSSelectorFromString([NSString stringWithFormat:@"set%@%@WithString:",
                                                 [[key substringToIndex:1] uppercaseString],
                                                 [key substringFromIndex:1]]);
        
        if ([self respondsToSelector:stringSetter])
        {
            //call the setStringValue setter
            objc_msgSend(self, stringSetter, stringValue);
        }
        else
        {
            NSString *type = [self SC_propertyTypeForKey:key];
            if (type)
            {
                [self setValue:[stringValue valueForType:type] forKey:key];
            }
            else
            {
#ifdef DEBUG
                [NSException raise:StringCodingErrorDomain format:@"StringCoding could not determine type of %@ property of %@. Implement the %@ method to manually set this property.", key, [self class], NSStringFromSelector(stringSetter)];
#else
                NSLog(@"Could not determine type for %@ property of %@", key, [self class]);
#endif
            }
        }
    }
}

- (void)setStringValue:(NSString *)value forKeyPath:(NSString *)keyPath
{
    NSMutableArray *parts = [[keyPath componentsSeparatedByString:@"."] mutableCopy];
    NSString *key = [parts lastObject];
    [parts removeLastObject];
    id object = [parts count]? [self valueForKeyPath:[parts componentsJoinedByString:@"."]]: self;
    if ([key hasPrefix:@"@"])
    {
        [object setStringValue:value forKey:[key substringFromIndex:1]];
    }
    else if ([object isKindOfClass:[NSArray class]] || [object isKindOfClass:[NSSet class]])
    {
        for (id item in object)
        {
            [item setStringValue:value forKey:key];
        }
    }
    else if ([object isKindOfClass:[NSDictionary class]])
    {
        for (id item in [object allValues])
        {
            [item setStringValue:value forKey:key];
        }
    }
    else
    {
        [object setStringValue:value forKey:key];
    }
}

@end

@implementation NSString (StringCoding)

- (id)SC_imageValueOfClass:(Class)imageClass
{
    NSNumber *leftCap = nil;
    NSNumber *topCap = nil;
    NSMutableArray *parts = [[self componentsSeparatedByString:@" "] mutableCopy];
    if ([parts count] > 1)
    {
        NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
        formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
        topCap = [formatter numberFromString:[parts lastObject]];
        if (topCap)
        {
            [parts removeLastObject];
        }
        if ([parts count] > 2)
        {
            leftCap = [formatter numberFromString:parts[[parts count] - 2]];
        }
        if (leftCap)
        {
            [parts removeLastObject];
        }
        else
        {
            leftCap = topCap;
        }
    }
    NSString *path = [parts componentsJoinedByString:@" "];
    id image = [imageClass imageNamed:path];
    if (!image)
    {
        NSURL *imageURL = [path NSURLValue];
        if (imageURL)
        {
            NSData *data = [NSData dataWithContentsOfURL:imageURL];
            image = [[imageClass alloc] initWithData:data];
        }
    }
    if (topCap)
    {
        CGFloat width = [leftCap floatValue];
        NSInteger leftCapWidth = [leftCap integerValue];
        if (width != leftCapWidth && width <= 0.5f)
        {
            leftCapWidth = width * [image size].width;
        }
        CGFloat height = [topCap floatValue];
        NSInteger topCapHeight = [topCap integerValue];
        if (height != topCapHeight && height <= 0.5f)
        {
            topCapHeight = height * [image size].height;
        }
        SEL selector = NSSelectorFromString(@"stretchableImageWithLeftCapWidth:topCapHeight:");
        if (selector)
        {
            image = objc_msgSend(image, selector, leftCapWidth, topCapHeight);
        }
    }
    return image;
}

- (id)SC_colorValueOfClass:(Class)colorClass
{
    //convert to lowercase
    NSString *string = [self lowercaseString];
    
    //try standard colors
    static NSDictionary *colors = nil;
    if (colors == nil)
    {
        colors = @{@"black": [colorClass blackColor], // 0.0 white
                   @"darkgray": [colorClass darkGrayColor], // 0.333 white
                   @"lightgray":[colorClass lightGrayColor], // 0.667 white
                   @"white": [colorClass whiteColor], // 1.0 white
                   @"gray": [colorClass grayColor], // 0.5 white
                   @"red": [colorClass redColor], // 1.0, 0.0, 0.0 RGB
                   @"green": [colorClass greenColor], // 0.0, 1.0, 0.0 RGB
                   @"blue": [colorClass blueColor], // 0.0, 0.0, 1.0 RGB
                   @"cyan": [colorClass cyanColor], // 0.0, 1.0, 1.0 RGB
                   @"yellow": [colorClass yellowColor], // 1.0, 1.0, 0.0 RGB
                   @"magenta": [colorClass magentaColor], // 1.0, 0.0, 1.0 RGB
                   @"orange": [colorClass orangeColor], // 1.0, 0.5, 0.0 RGB
                   @"purple": [colorClass purpleColor], // 0.5, 0.0, 0.5 RGB
                   @"brown": [colorClass brownColor], // 0.6, 0.4, 0.2 RGB
                   @"clear": [colorClass clearColor]};
    }
    UIColor *color = colors[string];
    if (color)
    {
        return color;
    }
    
    //try image
    id image = [self SC_imageValue];
    if (image)
    {
        return [colorClass colorWithPatternImage:image];
    }
    
    //color constructor
    SEL selector = NSSelectorFromString(@"colorWithDeviceRed:green:blue:alpha:");
    if (![colorClass respondsToSelector:selector])
    {
        selector = NSSelectorFromString(@"colorWithRed:green:blue:alpha:");
    }
    id (*constructor)(id, SEL, CGFloat, CGFloat, CGFloat, CGFloat)
    = (id (*)(id, SEL, CGFloat, CGFloat, CGFloat, CGFloat))[colorClass methodForSelector:selector];
    
    //try rgb(a)
    if ([string hasPrefix:@"rgb"])
    {
        string = [string substringToIndex:[string length] - 1];
        if ([string hasPrefix:@"rgb("])
        {
            string = [string substringFromIndex:4];
        }
        else if ([string hasPrefix:@"rgba("])
        {
            string = [string substringFromIndex:5];
        }
        CGFloat alpha = 1.0f;
        NSArray *components = [string componentsSeparatedByString:@","];
        if ([components count] > 3)
        {
            alpha = [[components[3] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] floatValue];
        }
        if ([components count] > 2)
        {
            NSString *red = [components[0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            NSString *green = [components[1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            NSString *blue = [components[2] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            return constructor(colorClass, selector,
                               [red floatValue] / 255.0f,
                               [green floatValue] / 255.0f,
                               [blue floatValue] / 255.0f,
                               alpha);
        }
        return nil;
    }
    
    //try hex
    string = [string stringByReplacingOccurrencesOfString:@"#" withString:@""];
    string = [string stringByReplacingOccurrencesOfString:@"0x" withString:@""];
    switch ([string length])
    {
        case 0:
        {
            string = @"00000000";
            break;
        }
        case 3:
        {
            NSString *red = [string substringWithRange:NSMakeRange(0, 1)];
            NSString *green = [string substringWithRange:NSMakeRange(1, 1)];
            NSString *blue = [string substringWithRange:NSMakeRange(2, 1)];
            string = [NSString stringWithFormat:@"%1$@%1$@%2$@%2$@%3$@%3$@ff", red, green, blue];
            break;
        }
        case 6:
        {
            string = [string stringByAppendingString:@"ff"];
            break;
        }
        case 8:
        {
            //do nothing
            break;
        }
        default:
        {
            //unsupported format
            NSLog(@"Unsupported color string format: %@", string);
            string = @"00000000";
        }
    }
    unsigned rgba;
    NSScanner *scanner = [NSScanner scannerWithString:string];
    [scanner scanHexInt:&rgba];
    CGFloat red = ((rgba & 0xFF000000) >> 24) / 255.0f;
    CGFloat green = ((rgba & 0x00FF0000) >> 16) / 255.0f;
	CGFloat blue = ((rgba & 0x0000FF00) >> 8) / 255.0f;
	CGFloat alpha = (rgba & 0x000000FF) / 255.0f;
    return constructor(colorClass, selector, red, green, blue, alpha);
}

- (id)SC_fontValueOfClass:(Class)fontClass
{
    NSMutableArray *parts = [[self componentsSeparatedByString:@" "] mutableCopy];
    if ([parts count])
    {
        NSString *fontName = nil;
        CGFloat size = [[parts lastObject] floatValue];
        if (size > 0)
        {
            [parts removeLastObject];
        }
        else
        {
            size = [parts[0] floatValue];
            if (size > 0)
            {
                [parts removeObjectAtIndex:0];
            }
            else
            {
                size = [fontClass systemFontSize];
            }
        }
        fontName = [parts componentsJoinedByString:@" "];
        fontName = [fontName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        fontName = [fontName stringByReplacingOccurrencesOfString:@"\"" withString:@""];
        if ([fontName length])
        {
            if ([fontName compare:@"bold" options:NSCaseInsensitiveSearch] == NSOrderedSame)
            {
                return [fontClass boldSystemFontOfSize:size];
            }
            else if ([fontName compare:@"italic" options:NSCaseInsensitiveSearch] == NSOrderedSame)
            {
                SEL selector = NSSelectorFromString(@"italicSystemFontOfSize:");
                if ([fontClass respondsToSelector:selector])
                {
                    return objc_msgSend(fontClass, selector, size);
                }
                return [fontClass systemFontOfSize:size];
            }
            else
            {
                id font = [fontClass fontWithName:fontName size:size];
                if (font)
                {
                    return font;
                }
            }
        }
        return [fontClass systemFontOfSize:size];
    }
    return nil;
}

- (BOOL)isNumeric
{
    static NSNumberFormatter *formatter = nil;
    if (formatter == nil)
    {
        formatter = [[NSNumberFormatter alloc] init];
        formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
    }
    return [formatter numberFromString:self] != nil;
}

- (id)valueForType:(NSString *)type
{
    if ([self isKindOfClass:NSClassFromString(type)])
    {
        //return self
        return self;
    }
    else if (type)
    {
        //create cache
        static NSMutableDictionary *cacheByType = nil;
        if (cacheByType == nil)
        {
            cacheByType = [[NSMutableDictionary alloc] init];
        }
        NSCache *cache = cacheByType[type];
        if (cache == nil)
        {
            cache = [[NSCache alloc] init];
            cacheByType[type] = cache;
        }
        
        //check cache
        id value = [cache objectForKey:self];
        if (value) return [value isKindOfClass:[NSNull class]]? nil: value;
        
#ifdef DEBUG
        NSString *originalType = type;
#endif
        
        //determine type
        while (type)
        {
            NSString *getterName = nil;
            for (int attempt = 0; attempt < 3; attempt++)
            {
                switch (attempt)
                {
                    case 0:
                    {
                        getterName = [type stringByAppendingString:@"Value"];
                        break;
                    }
                    case 1:
                    {
                        if ([type hasPrefix:@"NS"])
                        {
                            getterName = [NSString stringWithFormat:@"%@%@Value",
                                          [[type substringWithRange:NSMakeRange(2,1)] lowercaseString],
                                          [type substringFromIndex:3]];
                        }
                        else
                        {
                            continue;
                        }
                        break;
                    }
                    case 2:
                    {
                        if ([type hasSuffix:@"Ref"])
                        {
                            getterName = [NSString stringWithFormat:@"%@Value",
                                          [type substringToIndex:[type length] - 3]];
                        }
                        else
                        {
                            continue;
                        }
                        break;
                    }
                }
                
                //get value
                if ([self respondsToSelector:NSSelectorFromString(getterName)])
                {
                    //return converted value
                    if ([type hasSuffix:@"Ref"])
                    {
                        value = objc_msgSend(self, NSSelectorFromString(getterName));
                    }
                    else
                    {
                        value = [self valueForKey:getterName];
                    }
                    [cache setObject:value ?: [NSNull null] forKey:self];
                    return value;
                }
            }
            
            //try superclass
            type = NSStringFromClass([NSClassFromString(type) superclass]);
            if ([type isEqualToString:@"NSObject"])
            {
#ifdef DEBUG
                [NSException raise:StringCodingErrorDomain format:@"No %@ method found on NSString", [originalType stringByAppendingString:@"Value"]];
#endif
                [cache setObject:[NSNull null] forKey:self];
                break;
            }
        }
    }
    return nil;
}

- (char)charValue
{
    if ([self length] == 0)
    {
        return NO;
    }
    else if ([self length] > 1)
    {
        if ([self hasPrefix:@"0x"])
        {
            //hex value
            unsigned result = 0;
            NSScanner *scanner = [NSScanner scannerWithString:self];
            [scanner setScanLocation:2];
            [scanner scanHexInt:&result];
            return result;
        }
        NSInteger number = [self intValue];
        if (number)
        {
            //decimal
            return MIN(255, number);
        }
        //bool
        return [self boolValue];
    }
    else
    {
        //single character
        return MIN(255, [self characterAtIndex:0]);
    }
}

- (Class)classValue
{
    return NSClassFromString(self);
}

- (NSURL *)NSURLValue
{
    if ([self isAbsolutePath])
    {
        //absolute file path
        return [NSURL fileURLWithPath:self];
    }
    else if ([self length])
    {
        //arbitrary url
        return [NSURL URLWithString:self relativeToURL:[[NSBundle mainBundle] resourceURL]];
    }
    return nil;
}

- (CGFontRef)CGFontValue
{
    CFStringRef nameRef = (__bridge CFStringRef)[self SC_fontValue].fontName;
    return (__bridge CGFontRef)CFBridgingRelease(CGFontCreateWithFontName(nameRef));
}

#ifdef __IPHONE_OS_VERSION_MAX_ALLOWED

- (CGPoint)CGPointValue
{
    NSArray *parts = [self componentsSeparatedByString:@" "];
    if ([parts count] == 2)
    {
        return CGPointMake([parts[0] floatValue], [parts[1] floatValue]);
    }
    return CGPointFromString(self);
}

- (CGSize)CGSizeValue
{
    NSArray *parts = [self componentsSeparatedByString:@" "];
    if ([parts count] == 2)
    {
        return CGSizeMake([parts[0] floatValue], [parts[1] floatValue]);
    }
    return CGSizeFromString(self);
}

- (CGRect)CGRectValue
{
    NSArray *parts = [self componentsSeparatedByString:@" "];
    if ([parts count] == 4)
    {
        return CGRectMake([parts[0] floatValue], // x
                          [parts[1] floatValue], // y
                          [parts[2] floatValue], // width
                          [parts[3] floatValue]); // height
    }
    return CGRectFromString(self);
}


- (CGColorRef)CGColorValue
{
    return [self UIColorValue].CGColor;
}

- (CGImageRef)CGImageValue
{
    return [self UIImageValue].CGImage;
}

- (UIColor *)UIColorValue
{
    return [self SC_colorValueOfClass:[UIColor class]];
}

- (UIImage *)SC_imageValue
{
    return [self UIImageValue];
}

- (UIImage *)UIImageValue
{
    return [self SC_imageValueOfClass:[UIImage class]];
}

- (UIFont *)SC_fontValue
{
    return [self UIFontValue];
}

- (UIFont *)UIFontValue
{
    return [self SC_fontValueOfClass:[UIFont class]];
}

- (UIEdgeInsets)UIEdgeInsetsValue
{
    NSArray *parts = [self componentsSeparatedByString:@" "];
    switch ([parts count])
    {
        case 4:
        {
            return UIEdgeInsetsMake([parts[0] floatValue], // top
                                    [parts[1] floatValue], // left
                                    [parts[2] floatValue], // bottom
                                    [parts[3] floatValue]); // right
        }
        case 3:
        {
            return UIEdgeInsetsMake([parts[0] floatValue], // top
                                    [parts[1] floatValue], // left
                                    [parts[2] floatValue], // bottom
                                    [parts[1] floatValue]); // right
        }
        case 2:
        {
            return UIEdgeInsetsMake([parts[0] floatValue], // top
                                    [parts[1] floatValue], // left
                                    [parts[0] floatValue], // bottom
                                    [parts[1] floatValue]); // right
        }
        case 1:
        {
            return UIEdgeInsetsMake([parts[0] floatValue], // top
                                    [parts[0] floatValue], // left
                                    [parts[0] floatValue], // bottom
                                    [parts[0] floatValue]); // right
        }
    }
    return UIEdgeInsetsFromString(self);
}

- (UIViewContentMode)UIViewContentModeValue
{
    static NSDictionary *enumValues = nil;
    if (enumValues == nil)
    {
        enumValues = @{@"scaletofill": @(UIViewContentModeScaleToFill),
                       @"scaleaspectfit": @(UIViewContentModeScaleAspectFit),
                       @"scaleaspectfill": @(UIViewContentModeScaleAspectFill),
                       @"redraw": @(UIViewContentModeRedraw),
                       @"center": @(UIViewContentModeCenter),
                       @"top": @(UIViewContentModeTop),
                       @"bottom": @(UIViewContentModeBottom),
                       @"left": @(UIViewContentModeLeft),
                       @"right": @(UIViewContentModeRight),
                       @"topleft": @(UIViewContentModeTopLeft),
                       @"topright": @(UIViewContentModeTopRight),
                       @"bottomleft": @(UIViewContentModeBottomLeft),
                       @"bottomright": @(UIViewContentModeBottomRight)};
    }
    static NSString *prefix = @"uiviewcontentmode";
    NSString *value = [self lowercaseString];
    if ([value hasPrefix:prefix])
    {
        value = [value substringFromIndex:[prefix length]];
    }
    return [enumValues[value] intValue];
}

- (NSTextAlignment)NSTextAlignmentValue
{
    static NSDictionary *enumValues = nil;
    if (enumValues == nil)
    {
        enumValues = @{@"left": @(NSTextAlignmentLeft),
                       @"center": @(NSTextAlignmentCenter),
                       @"right": @(NSTextAlignmentRight),
                       @"justified": @(NSTextAlignmentJustified),
                       @"natural": @(NSTextAlignmentNatural)};
    }
    static NSString *prefix = @"nstextalignment";
    NSString *value = [self lowercaseString];
    if ([value hasPrefix:prefix])
    {
        value = [value substringFromIndex:[prefix length]];
    }
    return [enumValues[value] intValue];
}

#else

- (NSPoint)NSPointValue
{
    NSArray *parts = [self componentsSeparatedByString:@" "];
    if ([parts count] == 2)
    {
        return NSMakePoint([parts[0] floatValue], [parts[1] floatValue]);
    }
    return NSPointFromString(self);
}

- (NSSize)NSSizeValue
{
    NSArray *parts = [self componentsSeparatedByString:@" "];
    if ([parts count] == 2)
    {
        return NSMakeSize([parts[0] floatValue], [parts[1] floatValue]);
    }
    return NSSizeFromString(self);
}

- (NSRect)NSRectValue
{
    NSArray *parts = [self componentsSeparatedByString:@" "];
    if ([parts count] == 4)
    {
        return NSMakeRect([parts[0] floatValue], // x
                          [parts[1] floatValue], // y
                          [parts[2] floatValue], // width
                          [parts[3] floatValue]); // height
    }
    return NSRectFromString(self);
}

- (NSColor *)NSColorValue
{
    return [self SC_colorValueOfClass:[NSColor class]];
}

- (NSImage *)SC_imageValue
{
    return [self NSImageValue];
}

- (NSImage *)NSImageValue
{
    return [self SC_imageValueOfClass:[NSImage class]];
}

- (NSFont *)SC_fontValue
{
    return [self NSFontValue];
}

- (NSFont *)NSFontValue
{
    return [self SC_fontValueOfClass:[NSFont class]];
}

- (CGPoint)CGPointValue
{
    return [self NSPointValue];
}

- (CGSize)CGSizeValue
{
    return [self NSSizeValue];
}

- (CGRect)CGRectValue
{
    return [self NSRectValue];
}

- (CGColorRef)CGColorValue
{
    return [self NSColorValue].CGColor;
}

- (CGImageRef)CGImageValue
{
    NSImage *image = [self NSImageValue];
    NSRect rect = NSMakeRect(0, 0, image.size.width, image.size.height);
    return [image CGImageForProposedRect:&rect context:NULL hints:nil];
}

- (NSTextAlignment)NSTextAlignmentValue
{
    static NSDictionary *enumValues = nil;
    if (enumValues == nil)
    {
        enumValues = @{@"left": @(NSLeftTextAlignment),
                       @"center": @(NSCenterTextAlignment),
                       @"right": @(NSRightTextAlignment),
                       @"justified": @(NSJustifiedTextAlignment),
                       @"natural": @(NSNaturalTextAlignment),
                       @"nslefttextalignment": @(NSLeftTextAlignment),
                       @"nscentertextalignment": @(NSCenterTextAlignment),
                       @"nsrighttextalignment": @(NSRightTextAlignment),
                       @"nsjustifiedtextalignment": @(NSJustifiedTextAlignment),
                       @"nsnaturaltextalignment": @(NSNaturalTextAlignment)};
    }
    NSString *value = [self lowercaseString];
    return [enumValues[value] intValue];
}

#endif

@end

@implementation CALayer (StringValues)

- (void)setContentsWithString:(NSString *)string
{
    self.contents = (id)[string CGImageValue];
}

@end

#ifdef __IPHONE_OS_VERSION_MAX_ALLOWED

@implementation UIView (StringValues)

- (void)setBackgroundColorWithString:(NSString *)string
{
    self.backgroundColor = [string UIColorValue];
}

- (void)setContentModeWithString:(NSString *)string
{
    self.contentMode = [string UIViewContentModeValue];
}

@end

@implementation UILabel (StringValues)

- (void)setTextAlignmentWithString:(NSString *)string
{
    self.textAlignment = [string NSTextAlignmentValue];
}

@end

#endif