//
//  StringCoding.m
//
//  Version 1.2
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
#import <objc/runtime.h>


#import <Availability.h>
#if !__has_feature(objc_arc)
#error This class requires automatic reference counting
#endif


#import <Availability.h>
#undef SC_weak
#if __has_feature(objc_arc_weak) && \
(!(defined __MAC_OS_X_VERSION_MIN_REQUIRED) || \
__MAC_OS_X_VERSION_MIN_REQUIRED >= __MAC_10_8)
#define SC_weak weak
#else
#define SC_weak unsafe_unretained
#endif


NSString *const StringCodingErrorDomain = @"StringCodingErrorDomain";


@interface NSString (StringCoding_Private)

- (id)SC_valueForTypeName:(NSString *)type;

@end


@implementation NSObject (StringCoding)

#if SC_SWIZZLE_ENABLED

static void SC_swizzleInstanceMethod(Class c, SEL original, SEL replacement)
{
    Method a = class_getInstanceMethod(c, original);
    Method b = class_getInstanceMethod(c, replacement);
    if (class_addMethod(c, original, method_getImplementation(b), method_getTypeEncoding(b)))
    {
        class_replaceMethod(c, replacement, method_getImplementation(a), method_getTypeEncoding(a));
    }
    else
    {
        method_exchangeImplementations(a, b);
    }
}

+ (void)load
{
    SC_swizzleInstanceMethod(self, @selector(setValue:forKey:), @selector(SC_setValue:forKey:));
    SC_swizzleInstanceMethod(self, @selector(setValue:forKeyPath:), @selector(SC_setValue:forKeyPath:));
}

- (void)SC_setValue:(id)value forKey:(NSString *)key
{
    if (![value isKindOfClass:[NSString class]] || [[self SC_typeNameForKey:key] isEqualToString:@"NSString"])
    {
        [self SC_setValue:value forKey:key];
    }
    else
    {
        [self setValueWithString:value forKey:key];
    }
}

- (void)SC_setValue:(id)value forKeyPath:(NSString *)keyPath
{
    if (![value isKindOfClass:[NSString class]])
    {
        [self SC_setValue:value forKeyPath:keyPath];
    }
    else
    {
        [self setValueWithString:value forKeyPath:keyPath];
    }
}

#endif

- (NSString *)SC_typeNameForKey:(NSString *)key
{
    //create cache
    static NSMutableDictionary *cacheByClass = nil;
    if (cacheByClass == nil)
    {
        cacheByClass = [[NSMutableDictionary alloc] init];
    }
    NSString *className = NSStringFromClass([self class]);
    NSMutableDictionary *cache = cacheByClass[className];
    if (cache == nil)
    {
        //create cache
        cache = [[NSMutableDictionary alloc] init];
        cacheByClass[className] = cache;
        
        //prepopulate with property types
        Class class = [self class];
        while (true)
        {
            unsigned int count;
            objc_property_t *properties = class_copyPropertyList(class, &count);
            for (int i = 0; i < count; i++)
            {
                objc_property_t property = properties[i];
                const char *name = property_getName(property);
                
                //get class
                NSString *class = nil;
                char *typeEncoding = property_copyAttributeValue(property, "T");
                if (strlen(typeEncoding) >= 3 && typeEncoding[0] == '@')
                {
                    char *className = strndup(typeEncoding + 2, strlen(typeEncoding) - 3);
                    class = [NSString stringWithUTF8String:className];
                    NSRange range = [class rangeOfString:@"<"];
                    if (range.location != NSNotFound)
                    {
                        //TODO: better handling of protocols
                        class = [class substringToIndex:range.location];
                    }
                    class = NSStringFromClass(NSClassFromString(class));
                    free(className);
                }
                free(typeEncoding);
                
                //set type
                if (class) cache[@(name)] = class;
            }
            free(properties);
            
            if (class == [NSObject class]) break;
            class = [class superclass];
        }
    }
    
    //check cache
    NSString *type = cache[key];
    if (type) return [type length]? type: nil;
    
    //get selector for setter method
    SEL setter = NSSelectorFromString([@"set" stringByAppendingFormat:@"%@%@:",
                                       [[key substringToIndex:1] uppercaseString],
                                       [key substringFromIndex:1]]);
    
    BOOL isPointer = NO;
    if ([self respondsToSelector:setter])
    {
        //get the first method argument
        Method method = class_getInstanceMethod([self class], setter);
        char *typeName = method_copyArgumentType(method, 2);
        
        if (typeName[0] == '^')
        {
            //handle pointer
            isPointer = YES;
            char *temp = typeName;
            size_t chars = strlen(temp) - 1;
            typeName = malloc(chars + 1);
            strlcpy(typeName, &temp[1], chars);
            free(temp);
        }
        
        switch (typeName[0])
        {
            case '@':
            {
                //object of unknown type
                type = @"NSObject";
                if ([self respondsToSelector:NSSelectorFromString(key)])
                {
                    //try deriving type from existing value
                    id value = [self valueForKey:key];
                    if (value)
                    {
                        type = NSStringFromClass([value class]);
                    }
                }
                break;
            }
            case '{':
            {
                //struct
                type = [@(typeName) substringFromIndex:1];
                NSRange range = [type rangeOfString:@"="];
                if (range.location != NSNotFound)
                {
                    type = [type substringToIndex:range.location];
                }
                break;
            }
            case 'c':
            case 'C':
            {
                type = @"char";
                break;
            }
            case 'i':
            case 'I':
            case 's':
            case 'S':
            case 'l':
            case 'L':
            {
                type = @"int";
                break;
            }
            case 'q':
            case 'Q':
            {
                type = @"longLong";
                break;
            }
            case 'f':
            {
                type = @"float";
                break;
            }
            case 'd':
            {
                type = @"double";
                break;
            }
            case 'B':
            {
                type = @"bool";
                break;
            }
            case '*':
            {
                type = @"UTFString";
                break;
            }
            case '#':
            {
                type = @"class";
                break;
            }
            case ':':
            {
                type = @"selector";
                break;
            }
            default:
            {
                break;
            }
        }
        
        //free name
        free(typeName);
    }
    else if ([self respondsToSelector:NSSelectorFromString(key)])
    {
        //try deriving type from existing value
        id value = [self valueForKey:key];
        if (value)
        {
            type = NSStringFromClass([value class]);
        }
    }
    
    //handle pointers
    if (isPointer)
    {
        type = [type stringByAppendingString:@"Ref"];
    }
    
    //cache and return type
    cache[key] = type ?: @"";
    return type;
}

- (BOOL)SC_callSetter:(NSString *)setterString withValue:(NSString *)value
{
    SEL setter = NSSelectorFromString(setterString);
    if ([self respondsToSelector:setter])
    {
        objc_msgSend(self, setter, value);
        return YES;
    }
    else
    {
        SEL setter = NSSelectorFromString([@"SC_" stringByAppendingString:setterString]);
        if ([self respondsToSelector:setter])
        {
            objc_msgSend(self, setter, value);
            return YES;
        }
        else
        {
            return NO;
        }
    }
}

- (void)setValueWithString:(NSString *)value forKey:(NSString *)key
{
    if ([key length])
    {
        NSString *setterString = [NSString stringWithFormat:@"set%@%@WithString:",
                                                 [[key substringToIndex:1] uppercaseString],
                                                 [key substringFromIndex:1]];
        
        if (![self SC_callSetter:setterString withValue:value])
        {
            NSString *type = [self SC_typeNameForKey:key];
            if (!type)
            {
                
#ifdef DEBUG
                [NSException raise:StringCodingErrorDomain format:@"StringCoding could not determine type of %@ property of %@. Implement the %@ method to manually set this property.", key, [self class], setterString];
#else
                NSLog(@"Could not determine type for %@ property of %@", key, [self class]);
#endif
                
            }
            else
            {
                [self setValue:[value SC_valueForTypeName:type] forKey:key];
            }
        }
    }
}

- (void)setValueWithString:(NSString *)value forKeyPath:(NSString *)keyPath
{
    NSMutableArray *parts = [[keyPath componentsSeparatedByString:@"."] mutableCopy];
    NSString *key = [parts lastObject];
    [parts removeLastObject];
    id object = [parts count]? [self valueForKeyPath:[parts componentsJoinedByString:@"."]]: self;
    if ([key hasPrefix:@"@"])
    {
        [object setValueWithString:value forKey:[key substringFromIndex:1]];
    }
    else if ([object isKindOfClass:[NSArray class]] || [object isKindOfClass:[NSSet class]])
    {
        for (id item in object)
        {
            [item setValueWithString:value forKey:key];
        }
    }
    else if ([object isKindOfClass:[NSDictionary class]])
    {
        for (id item in [object allValues])
        {
            [item setValueWithString:value forKey:key];
        }
    }
    else
    {
        [object setValueWithString:value forKey:key];
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
                size = [self SC_systemFontSize];
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

- (NSInteger)SC_enumValueInDictionary:(NSDictionary *)enumValuesByKey prefix:(NSString *)prefix
{
    NSString *value = [self lowercaseString];
    if ([value hasPrefix:prefix])
    {
        value = [value substringFromIndex:[prefix length]];
    }
    return [enumValuesByKey[value] integerValue];
}

- (NSUInteger)SC_bitmaskValueInDictionary:(NSDictionary *)maskValuesByKey prefix:(NSString *)prefix
{
    NSString *value = [self lowercaseString];
    NSArray *components = [maskValuesByKey allKeys];
    if (![value isEqualToString:@"all"])
    {
        components = [value componentsSeparatedByString:@" "];
    }
    NSUInteger values = 0;
    for (NSString *value in components)
    {
        if ([value hasPrefix:prefix])
        {
            values |= [maskValuesByKey[[value substringFromIndex:[prefix length]]] intValue];
        }
        else
        {
            values |= [maskValuesByKey[value] integerValue];
        }
    }
    return values;
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

- (id)SC_valueForTypeName:(NSString *)type
{
    if ([type isEqualToString:@"NSString"])
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
                SEL getter = NSSelectorFromString(getterName);
                if ([self respondsToSelector:getter])
                {
                    //return converted value
                    if ([type hasSuffix:@"Ref"])
                    {
                        value = objc_msgSend(self, getter);
                    }
                    else if ([getterName isEqualToString:@"selectorValue"])
                    {
                        SEL selector = NSSelectorFromString(self);
                        value = [NSValue valueWithPointer:selector];
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

- (NSString *)stringValue
{
    return self;
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
            unsigned int result = 0;
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

- (short)shortValue
{
    return [self intValue];
}

- (long)longValue
{
    return [self intValue];
}

- (unsigned char)unsignedCharValue
{
    return [self charValue];
}

- (unsigned int)unsignedIntValue
{
    return [self intValue];
}

- (unsigned long)unsignedLongValue
{
    return [self intValue];
}

- (unsigned long long)unsignedLongLongValue
{
    return [self longLongValue];
}

- (Class)classValue
{
    return NSClassFromString(self);
}

- (SEL)selectorValue
{
    return NSSelectorFromString(self);
}

- (NSURL *)SC_NSURLValueRelativeToURL:(NSURL *)baseURL
{
    if ([self isAbsolutePath])
    {
        //absolute file path
        return [NSURL fileURLWithPath:self];
    }
    else if ([self length])
    {
        //arbitrary url
        return [NSURL URLWithString:self relativeToURL:baseURL ?: [[NSBundle mainBundle] resourceURL]];
    }
    return nil;
}

- (NSURL *)NSURLValue
{
    return [self SC_NSURLValueRelativeToURL:nil];
}

- (NSURLRequest *)SC_NSURLRequestValueRelativeToURL:(NSURL *)baseURL
{
    NSString *URLString = self;
    NSArray *components = [self componentsSeparatedByString:@" "];
    NSString *method = @"GET";
    if ([components count] > 1)
    {
        static NSSet *methods = nil;
        if (methods == nil)
        {
            methods = [[NSSet alloc] initWithArray:@[@"GET", @"PUT", @"POST", @"DELETE", @"HEAD", @"OPTIONS"]];
        }
        method = [components[0] uppercaseString];
        if ([methods containsObject:method])
        {
            URLString = [[components subarrayWithRange:NSMakeRange(1, [components count] - 1)] componentsJoinedByString:@" "];
        }
        else
        {
            method = @"GET";
        }
    }
    NSURL *URL = [URLString SC_NSURLValueRelativeToURL:baseURL];
    if (URL)
    {
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
        request.HTTPMethod = method;
        return request;
    }
    return nil;
}

- (NSURLRequest *)NSURLRequestValue
{
    return [self SC_NSURLRequestValueRelativeToURL:nil];
}

- (NSNumber *)NSNumberValue
{
    static NSNumberFormatter *formatter = nil;
    if (formatter == nil)
    {
        formatter = [[NSNumberFormatter alloc] init];
        formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
    }
    NSNumber *number = [formatter numberFromString:self];
    if (number)
    {
        return number;
    }
    else if ([self hasPrefix:@"0x"])
    {
        //hex value
        unsigned long long result = 0;
        NSScanner *scanner = [NSScanner scannerWithString:self];
        [scanner setScanLocation:2];
        [scanner scanHexLongLong:&result];
        return @(result);
    }
    else
    {
        static NSSet *booleanValues = nil;
        if (!booleanValues)
        {
            booleanValues = [[NSSet alloc] initWithArray:@[@"true", @"false", @"yes", @"no", @"y", @"n"]];
        }
        if ([booleanValues containsObject:[self lowercaseString]])
        {
            return @([self boolValue]);
        }
        return nil;
    }
}

- (const char *)UTF8StringValue
{
    //special case
    return [self UTF8String];
}

- (CGFontRef)CGFontValue
{
    CFStringRef nameRef = (__bridge CFStringRef)[self SC_fontValue].fontName;
    return (__bridge CGFontRef)CFBridgingRelease(CGFontCreateWithFontName(nameRef));
}

- (NSLineBreakMode)NSLineBreakModeValue
{
    static NSDictionary *enumValues = nil;
    if (enumValues == nil)
    {
        enumValues = @{@"wordwrapping": @(NSLineBreakByWordWrapping),
                       @"charwrapping": @(NSLineBreakByCharWrapping),
                       @"clipping": @(NSLineBreakByClipping),
                       @"truncatinghead": @(NSLineBreakByTruncatingHead),
                       @"truncatingtail": @(NSLineBreakByTruncatingTail),
                       @"truncatingmiddle": @(NSLineBreakByTruncatingMiddle),
                       
                       //added for convenience
                       @"wordwrapped": @(NSLineBreakByWordWrapping),
                       @"wordwrap": @(NSLineBreakByWordWrapping),
                       @"wrapped": @(NSLineBreakByWordWrapping),
                       @"wrap": @(NSLineBreakByWordWrapping),
                       @"charwrapped": @(NSLineBreakByCharWrapping),
                       @"charwrap": @(NSLineBreakByCharWrapping),
                       @"clipped": @(NSLineBreakByClipping),
                       @"clip": @(NSLineBreakByClipping),
                       @"truncatehead": @(NSLineBreakByTruncatingHead),
                       @"truncatetail": @(NSLineBreakByTruncatingTail),
                       @"truncated": @(NSLineBreakByTruncatingTail),
                       @"truncate": @(NSLineBreakByTruncatingTail),
                       @"truncatemiddle": @(NSLineBreakByTruncatingMiddle)};
    }
    return [self SC_enumValueInDictionary:enumValues prefix:@"nslinebreakby"];
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

- (CGFloat)SC_systemFontSize
{
    //systemFontSize returns 14 on iOS, which is clearly wrong
    return 17.0f;
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

- (UIOffset)UIOffsetValue
{
    NSArray *parts = [self componentsSeparatedByString:@" "];
    switch ([parts count])
    {
        case 2:
        {
            return UIOffsetMake([parts[0] floatValue], // horizontal
                                [parts[1] floatValue]); // vertical
        }
        case 1:
        {
            return UIOffsetMake([parts[0] floatValue], // horizontal
                                [parts[0] floatValue]); // vertical
        }
    }
    return UIOffsetFromString(self);
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
                       @"bottomright": @(UIViewContentModeBottomRight),
                       
                       //added for convenience
                       @"scale": @(UIViewContentModeScaleToFill),
                       @"aspectfit": @(UIViewContentModeScaleAspectFit),
                       @"fit": @(UIViewContentModeScaleAspectFit),
                       @"aspectfill": @(UIViewContentModeScaleAspectFill),
                       @"fill": @(UIViewContentModeScaleAspectFill)};
    }
    return [self SC_enumValueInDictionary:enumValues prefix:@"uiviewcontentmode"];
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
    return [self SC_enumValueInDictionary:enumValues prefix:@"nstextalignment"];
}

- (UIViewAutoresizing)UIViewAutoresizingValue
{
    static NSDictionary *enumValues = nil;
    if (enumValues == nil)
    {
        enumValues = @{@"none": @(UIViewAutoresizingNone),
                       @"flexibleleftmargin": @(UIViewAutoresizingFlexibleLeftMargin),
                       @"flexiblewidth": @(UIViewAutoresizingFlexibleWidth),
                       @"flexiblerightmargin": @(UIViewAutoresizingFlexibleRightMargin),
                       @"flexibletopmargin": @(UIViewAutoresizingFlexibleTopMargin),
                       @"flexibleheight": @(UIViewAutoresizingFlexibleHeight),
                       @"flexiblebottommargin": @(UIViewAutoresizingFlexibleBottomMargin),
                       
                       //added for convenience
                       @"leftmargin": @(UIViewAutoresizingFlexibleLeftMargin),
                       @"left": @(UIViewAutoresizingFlexibleLeftMargin),
                       @"width": @(UIViewAutoresizingFlexibleWidth),
                       @"rightmargin": @(UIViewAutoresizingFlexibleRightMargin),
                       @"right": @(UIViewAutoresizingFlexibleRightMargin),
                       @"topmargin": @(UIViewAutoresizingFlexibleTopMargin),
                       @"top": @(UIViewAutoresizingFlexibleTopMargin),
                       @"height": @(UIViewAutoresizingFlexibleHeight),
                       @"bottommargin": @(UIViewAutoresizingFlexibleBottomMargin),
                       @"bottom": @(UIViewAutoresizingFlexibleBottomMargin)};
    }
    return [self SC_bitmaskValueInDictionary:enumValues prefix:@"uiviewautoresizing"];
}

- (UIBaselineAdjustment)UIBaselineAdjustment
{
    static NSDictionary *enumValues = nil;
    if (enumValues == nil)
    {
        enumValues = @{@"alignbaselines": @(UIBaselineAdjustmentAlignBaselines),
                       @"aligncenters": @(UIBaselineAdjustmentAlignCenters),
                       @"none": @(UIBaselineAdjustmentNone),
                       
                       //added for convenience
                       @"baselines": @(UIBaselineAdjustmentAlignBaselines),
                       @"baseline": @(UIBaselineAdjustmentAlignBaselines),
                       @"centers": @(UIBaselineAdjustmentAlignCenters),
                       @"center": @(UIBaselineAdjustmentAlignCenters),
                       @"centered": @(UIBaselineAdjustmentAlignCenters)};
    }
    return [self SC_enumValueInDictionary:enumValues prefix:@"uibaselineadjustment"];
}

- (NSDictionary *)SC_controlStates
{
    static NSDictionary *enumValues = nil;
    if (enumValues == nil)
    {
        enumValues = @{@"normal": @(UIControlStateNormal),
                       @"highlighted": @(UIControlStateHighlighted),
                       @"disabled": @(UIControlStateDisabled),
                       @"selected": @(UIControlStateSelected)};
    }
    return enumValues;
}

- (UIControlState)UIControlStateValue
{
    return [self SC_bitmaskValueInDictionary:[self SC_controlStates] prefix:@"uicontrolstate"];
}

- (UIControlEvents)UIControlEventsValue
{
    static NSDictionary *enumValues = nil;
    if (enumValues == nil)
    {
        enumValues = @{@"touchdown": @(UIControlEventTouchDown),
                       @"touchdownrepeat": @(UIControlEventTouchDownRepeat),
                       @"touchdraginside": @(UIControlEventTouchDragInside),
                       @"touchdragoutside": @(UIControlEventTouchDragOutside),
                       @"touchdragenter": @(UIControlEventTouchDragEnter),
                       @"touchdragexit": @(UIControlEventTouchDragExit),
                       @"touchupinside": @(UIControlEventTouchUpInside),
                       @"touchupoutside": @(UIControlEventTouchUpOutside),
                       @"touchcancel": @(UIControlEventTouchCancel),
                       @"valuechanged": @(UIControlEventValueChanged),
                       @"editingdidbegin": @(UIControlEventEditingDidBegin),
                       @"editingchanged": @(UIControlEventEditingChanged),
                       @"editingdidend": @(UIControlEventEditingDidEnd),
                       @"editingdidendonexit": @(UIControlEventEditingDidEndOnExit),
                       @"allTouchevents": @(UIControlEventAllTouchEvents),
                       @"alleditingevents": @(UIControlEventAllEditingEvents),
                       @"allevents": @(UIControlEventAllEvents)};
    }
    return [self SC_bitmaskValueInDictionary:enumValues prefix:@"uicontrolevent"];
}

- (UITextBorderStyle)UITextBorderStyleValue
{
    static NSDictionary *enumValues = nil;
    if (enumValues == nil)
    {
        enumValues = @{@"none": @(UITextBorderStyleNone),
                       @"line": @(UITextBorderStyleLine),
                       @"bezel": @(UITextBorderStyleBezel),
                       @"roundedrect": @(UITextBorderStyleRoundedRect)};
    }
    return [self SC_enumValueInDictionary:enumValues prefix:@"uitextborderstyle"];
}

- (UITextFieldViewMode)UITextFieldViewModeValue
{
    static NSDictionary *enumValues = nil;
    if (enumValues == nil)
    {
        enumValues = @{@"never": @(UITextFieldViewModeNever),
                       @"whileediting": @(UITextFieldViewModeWhileEditing),
                       @"unlessediting": @(UITextFieldViewModeUnlessEditing),
                       @"always": @(UITextFieldViewModeAlways)};
    }
    return [self SC_enumValueInDictionary:enumValues prefix:@"uitextfieldviewmode"];
}

- (UIDataDetectorTypes)UIDataDetectorTypesValue
{
    static NSDictionary *enumValues = nil;
    if (enumValues == nil)
    {
        enumValues = @{@"phonenumber": @(UIDataDetectorTypePhoneNumber),
                       @"link": @(UIDataDetectorTypeLink),
                       @"address": @(UIDataDetectorTypeAddress),
                       @"calendarevent": @(UIDataDetectorTypeCalendarEvent),
                       @"none": @(UIDataDetectorTypeNone),
                       @"all": @(UIDataDetectorTypeNone),
                       
                       //added for convenience
                       @"phone": @(UIDataDetectorTypePhoneNumber),
                       @"calendar": @(UIDataDetectorTypeCalendarEvent)};
    }
    return [self SC_bitmaskValueInDictionary:enumValues prefix:@"uidatadetectortype"];
}

- (UIScrollViewIndicatorStyle)UIScrollViewIndicatorStyleValue
{
    static NSDictionary *enumValues = nil;
    if (enumValues == nil)
    {
        enumValues = @{@"default": @(UIScrollViewIndicatorStyleDefault),
                       @"black": @(UIScrollViewIndicatorStyleBlack),
                       @"white": @(UIScrollViewIndicatorStyleWhite)};
    }
    return [self SC_enumValueInDictionary:enumValues prefix:@"uiscrollviewindicatorstyle"];
}

- (UITableViewStyle)UITableViewStyleValue
{
    static NSDictionary *enumValues = nil;
    if (enumValues == nil)
    {
        enumValues = @{@"plain": @(UITableViewStylePlain),
                       @"grouped": @(UITableViewStyleGrouped)};
    }
    return [self SC_enumValueInDictionary:enumValues prefix:@"uitableviewstyle"];
}

- (UITableViewScrollPosition)UITableViewScrollPositionValue
{
    static NSDictionary *enumValues = nil;
    if (enumValues == nil)
    {
        enumValues = @{@"none": @(UITableViewScrollPositionNone),
                       @"top": @(UITableViewScrollPositionTop),
                       @"middle": @(UITableViewScrollPositionMiddle),
                       @"bottom": @(UITableViewScrollPositionBottom)};
    }
    return [self SC_enumValueInDictionary:enumValues prefix:@"uitableviewscrollposition"];
}

- (UITableViewRowAnimation)UITableViewRowAnimationValue
{
    static NSDictionary *enumValues = nil;
    if (enumValues == nil)
    {
        enumValues = @{@"fade": @(UITableViewRowAnimationFade),
                       @"right": @(UITableViewRowAnimationRight),
                       @"left": @(UITableViewRowAnimationLeft),
                       @"top": @(UITableViewRowAnimationTop),
                       @"bottom": @(UITableViewRowAnimationBottom),
                       @"none": @(UITableViewRowAnimationNone),
                       @"middle": @(UITableViewRowAnimationMiddle),
                       @"automatic": @(UITableViewRowAnimationAutomatic)};
    }
    return [self SC_enumValueInDictionary:enumValues prefix:@"uitableviewrowanimation"];
}

- (UITableViewCellStyle)UITableViewCellStyleValue
{
    static NSDictionary *enumValues = nil;
    if (enumValues == nil)
    {
        enumValues = @{@"default": @(UITableViewCellStyleDefault),
                       @"value1": @(UITableViewCellStyleValue1),
                       @"value2": @(UITableViewCellStyleValue2),
                       @"subtitle": @(UITableViewCellStyleSubtitle),
                       
                       //added for convenience
                       @"1": @(UITableViewCellStyleValue1),
                       @"type1": @(UITableViewCellStyleValue1),
                       @"style1": @(UITableViewCellStyleValue1),
                       @"2": @(UITableViewCellStyleValue2),
                       @"type2": @(UITableViewCellStyleValue2),
                       @"style2": @(UITableViewCellStyleValue2)};
    }
    return [self SC_enumValueInDictionary:enumValues prefix:@"uitableviewcellstyle"];
}

- (UITableViewCellSeparatorStyle)UITableViewCellSeparatorStyleValue
{
    static NSDictionary *enumValues = nil;
    if (enumValues == nil)
    {
        enumValues = @{@"none": @(UITableViewCellSeparatorStyleNone),
                       @"singleline": @(UITableViewCellSeparatorStyleSingleLine),
                       @"singlelineetched": @(UITableViewCellSeparatorStyleSingleLineEtched),
                       
                       //added for convenience
                       @"line": @(UITableViewCellSeparatorStyleSingleLine),
                       @"lineetched": @(UITableViewCellSeparatorStyleSingleLineEtched),
                       @"etchedline": @(UITableViewCellSeparatorStyleSingleLineEtched),
                       @"etched": @(UITableViewCellSeparatorStyleSingleLineEtched)};
    }
    return [self SC_enumValueInDictionary:enumValues prefix:@"uitableviewcellseparatorstyle"];
}

- (UITableViewCellSelectionStyle)UITableViewCellSelectionStyleValue
{
    static NSDictionary *enumValues = nil;
    if (enumValues == nil)
    {
        enumValues = @{@"none": @(UITableViewCellSelectionStyleNone),
                       @"blue": @(UITableViewCellSelectionStyleBlue),
                       @"gray": @(UITableViewCellSelectionStyleGray)};
    }
    return [self SC_enumValueInDictionary:enumValues prefix:@"uitableviewcellselectionstyle"];
}

- (UITableViewCellEditingStyle)UITableViewCellEditingStyleValue
{
    static NSDictionary *enumValues = nil;
    if (enumValues == nil)
    {
        enumValues = @{@"none": @(UITableViewCellEditingStyleNone),
                       @"delete": @(UITableViewCellEditingStyleDelete),
                       @"insert": @(UITableViewCellEditingStyleInsert)};
    }
    return [self SC_enumValueInDictionary:enumValues prefix:@"uitableviewcelleditingstyle"];
}

- (UITableViewCellAccessoryType)UITableViewCellAccessoryTypeValue
{
    static NSDictionary *enumValues = nil;
    if (enumValues == nil)
    {
        enumValues = @{@"none": @(UITableViewCellAccessoryNone),
                       @"disclosureindicator": @(UITableViewCellAccessoryDisclosureIndicator),
                       @"disclosurebutton": @(UITableViewCellAccessoryDetailDisclosureButton),
                       @"checkmark": @(UITableViewCellAccessoryCheckmark),
                       
                       //added for convenience
                       @"disclosurearrow": @(UITableViewCellAccessoryDisclosureIndicator),
                       @"chevron": @(UITableViewCellAccessoryDisclosureIndicator),
                       @"button": @(UITableViewCellAccessoryDetailDisclosureButton),
                       @"tick": @(UITableViewCellAccessoryCheckmark)};
    }
    return [self SC_enumValueInDictionary:enumValues prefix:@"uitableviewcellaccessory"];
}

- (UITableViewCellStateMask)UITableViewCellStateMaskValue
{
    static NSDictionary *enumValues = nil;
    if (enumValues == nil)
    {
        enumValues = @{@"default": @(UITableViewCellStateDefaultMask),
                       @"showingeditcontrolmask": @(UITableViewCellStateShowingEditControlMask),
                       @"showingdeleteconfirmationmask": @(UITableViewCellStateShowingDeleteConfirmationMask),
                       
                       //added for convenience
                       @"editcontrolmask": @(UITableViewCellStateShowingEditControlMask),
                       @"editcontrol": @(UITableViewCellStateShowingEditControlMask),
                       @"edit": @(UITableViewCellStateShowingEditControlMask),
                       @"deleteconfirmationmask": @(UITableViewCellStateShowingDeleteConfirmationMask),
                       @"deleteconfirmation": @(UITableViewCellStateShowingDeleteConfirmationMask),
                       @"delete": @(UITableViewCellStateShowingDeleteConfirmationMask)};
    }
    return [self SC_bitmaskValueInDictionary:enumValues prefix:@"uitableviewcellstate"];
}

- (UIButtonType)UIButtonTypeValue
{
    static NSDictionary *enumValues = nil;
    if (enumValues == nil)
    {
        enumValues = @{@"custom": @(UIButtonTypeCustom),
                       @"roundedrect": @(UIButtonTypeRoundedRect),
                       @"detaildisclosure": @(UIButtonTypeDetailDisclosure),
                       @"infolight": @(UIButtonTypeInfoLight),
                       @"infodark": @(UIButtonTypeInfoDark),
                       @"contactadd": @(UIButtonTypeContactAdd),
                       
                       //added for convenience
                       @"default": @(UIButtonTypeRoundedRect),
                       @"disclosure": @(UIButtonTypeDetailDisclosure),
                       @"info": @(UIButtonTypeInfoLight),
                       @"addcontact": @(UIButtonTypeContactAdd)};
    }
    return [self SC_enumValueInDictionary:enumValues prefix:@"uibuttontype"];
}

- (UIBarStyle)UIBarStyleValue
{
    static NSDictionary *enumValues = nil;
    if (enumValues == nil)
    {
        enumValues = @{@"default": @(UIBarStyleDefault),
                       @"black": @(UIBarStyleBlack),
                       
                       //deprecated
                       @"blackopaque": @(UIBarStyleBlackOpaque),
                       @"blacktranslucent": @(UIBarStyleBlackTranslucent)};
    }
    return [self SC_enumValueInDictionary:enumValues prefix:@"uibarstyle"];
}

- (UIBarMetrics)UIBarMetricsValue
{
    static NSDictionary *enumValues = nil;
    if (enumValues == nil)
    {
        enumValues = @{@"default": @(UIBarMetricsDefault),
                       @"landscapephone": @(UIBarMetricsLandscapePhone),
                       
                       //added for convenience
                       @"landscape": @(UIBarMetricsLandscapePhone)};
    }
    return [self SC_enumValueInDictionary:enumValues prefix:@"uibarmetrics"];
}

- (UIBarButtonItemStyle)UIBarButtonItemStyleValue
{
    static NSDictionary *enumValues = nil;
    if (enumValues == nil)
    {
        enumValues = @{@"plain": @(UIBarButtonItemStylePlain),
                       @"bordered": @(UIBarButtonItemStyleBordered),
                       @"done": @(UIBarButtonItemStyleDone)};
    }
    return [self SC_enumValueInDictionary:enumValues prefix:@"uibarbuttonitemstyle"];
}

- (UIBarButtonSystemItem)UIBarButtonSystemItemValue
{
    static NSDictionary *enumValues = nil;
    if (enumValues == nil)
    {
        enumValues = @{@"done": @(UIBarButtonSystemItemDone),
                       @"cancel": @(UIBarButtonSystemItemCancel),
                       @"edit": @(UIBarButtonSystemItemEdit),
                       @"save": @(UIBarButtonSystemItemSave),
                       @"add": @(UIBarButtonSystemItemAdd),
                       @"flexiblespace": @(UIBarButtonSystemItemFlexibleSpace),
                       @"fixedspace": @(UIBarButtonSystemItemFixedSpace),
                       @"compose": @(UIBarButtonSystemItemCompose),
                       @"action": @(UIBarButtonSystemItemAction),
                       @"organize": @(UIBarButtonSystemItemOrganize),
                       @"bookmarks": @(UIBarButtonSystemItemBookmarks),
                       @"search": @(UIBarButtonSystemItemSearch),
                       @"refresh": @(UIBarButtonSystemItemRefresh),
                       @"stop": @(UIBarButtonSystemItemStop),
                       @"camera": @(UIBarButtonSystemItemCamera),
                       @"trash": @(UIBarButtonSystemItemTrash),
                       @"play": @(UIBarButtonSystemItemPlay),
                       @"pause": @(UIBarButtonSystemItemPause),
                       @"rewind": @(UIBarButtonSystemItemRewind),
                       @"fastforward": @(UIBarButtonSystemItemFastForward),
                       @"undo": @(UIBarButtonSystemItemUndo),
                       @"redo": @(UIBarButtonSystemItemRedo),
                       @"pagecurl": @(UIBarButtonSystemItemPageCurl)};
    }
    return [self SC_enumValueInDictionary:enumValues prefix:@"uibarbuttonsystemitem"];
}

- (UITabBarSystemItem)UITabBarSystemItemValue
{
    static NSDictionary *enumValues = nil;
    if (enumValues == nil)
    {
        enumValues = @{@"more": @(UITabBarSystemItemMore),
                       @"favorites": @(UITabBarSystemItemFavorites),
                       @"featured": @(UITabBarSystemItemFeatured),
                       @"toprated": @(UITabBarSystemItemTopRated),
                       @"recents": @(UITabBarSystemItemRecents),
                       @"contacts": @(UITabBarSystemItemContacts),
                       @"history": @(UITabBarSystemItemHistory),
                       @"bookmarks": @(UITabBarSystemItemBookmarks),
                       @"search": @(UITabBarSystemItemSearch),
                       @"downloads": @(UITabBarSystemItemDownloads),
                       @"mostrecent": @(UITabBarSystemItemMostRecent),
                       @"mostviewed": @(UITabBarSystemItemMostViewed)};
    }
    return [self SC_enumValueInDictionary:enumValues prefix:@"uitabbarsystemitem"];
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

- (CGFloat)SC_systemFontSize
{
    return [NSFont systemFontSize];
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
    return [self SC_enumValueInDictionary:enumValues prefix:nil];
}

#endif

@end

@implementation CALayer (StringValues)

- (NSString *)SC_typeNameForKey:(NSString *)key
{
    static NSDictionary *types = nil;
    if (types == nil)
    {
        types = @{@"contents": @"CGImageRef"};
    }
    return types[key] ?: [super SC_typeNameForKey:key];
}

@end

#ifdef __IPHONE_OS_VERSION_MAX_ALLOWED

@implementation UIView (StringValues)

- (NSString *)SC_typeNameForKey:(NSString *)key
{
    static NSDictionary *types = nil;
    if (types == nil)
    {
        types = @{@"backgroundColor": @"UIColor",
                  @"contentMode": @"UIViewContentMode",
                  @"autoresizingMask": @"UIViewAutoresizing",
                  @"restorationIdentifier": @"NSString"};
    }
    return types[key] ?: [super SC_typeNameForKey:key];
}

@end

@implementation UILabel (StringValues)

- (NSString *)SC_typeNameForKey:(NSString *)key
{
    static NSDictionary *types = nil;
    if (types == nil)
    {
        types = @{@"textAlignment": @"NSTextAlignment",
                  @"lineBreakMode": @"NSLineBreakMode",
                  @"baselineAdjustment": @"UIBaselineAdjustment"};
    }
    return types[key] ?: [super SC_typeNameForKey:key];
}

@end

@implementation UITextView (StringValues)

- (NSString *)SC_typeNameForKey:(NSString *)key
{
    static NSDictionary *types = nil;
    if (types == nil)
    {
        types = @{@"textAlignment": @"NSTextAlignment",
                  @"dataDetectorTypes": @"UITextBorderStyle"};
    }
    return types[key] ?: [super SC_typeNameForKey:key];
}

@end

@implementation UIScrollView (StringValues)

- (NSString *)SC_typeNameForKey:(NSString *)key
{
    static NSDictionary *types = nil;
    if (types == nil)
    {
        types = @{@"contentInset": @"UIEdgeInsets",
                  @"scrollIndicatorInsets": @"UIEdgeInsets",
                  @"scrollIndicatorStyle": @"UIScrollViewIndicatorStyle"};
    }
    return types[key] ?: [super SC_typeNameForKey:key];
}

@end

@implementation UITableView (StringValues)

- (NSString *)SC_typeNameForKey:(NSString *)key
{
    static NSDictionary *types = nil;
    if (types == nil)
    {
        types = @{@"style": @"UITableViewStyle",
                  @"separatorStyle": @"UITableViewCellSeparatorStyle"};
    }
    return types[key] ?: [super SC_typeNameForKey:key];
}

@end

@implementation UITableViewCell (StringValues)

- (NSString *)SC_typeNameForKey:(NSString *)key
{
    static NSDictionary *types = nil;
    if (types == nil)
    {
        types = @{@"style": @"UITableViewCellStyle",
                  @"selectionStyle": @"UITableViewCellSelectionStyle",
                  @"editingStyle": @"UITableViewCellEditingStyle",
                  @"accessoryType": @"UITableViewCellAccessoryType",
                  @"editingAccessoryType": @"UITableViewCellAccessoryType"};
    }
    return types[key] ?: [super SC_typeNameForKey:key];
}

@end


@interface SCActionTarget : NSObject

@property (nonatomic, SC_weak) id sender;

@end


@implementation SCActionTarget

- (id)forwardingTargetForSelector:(SEL)selector
{
    //find first object in responder chain that responds to selector
    id responder = _sender;
    while ((responder = [responder nextResponder]))
    {
        if ([responder respondsToSelector:selector])
        {
            return responder;
        }
        else if ([responder isKindOfClass:[UINavigationBar class]])
        {
            UINavigationController *controller = (UINavigationController *)[[responder nextResponder] nextResponder];
            responder = [controller topViewController];
            if ([responder respondsToSelector:selector])
            {
                return responder;
            }
        }
    }
    return nil;
}

@end


@implementation UIControl (StringCoding)

- (id)SC_actionTarget
{
    SCActionTarget *target = objc_getAssociatedObject(self, _cmd);
    if (!target)
    {
        target = [[SCActionTarget alloc] init];
        target.sender = self;
        objc_setAssociatedObject(self, _cmd, target, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return target;
}

- (void)setValueWithString:(NSString *)value forKey:(NSString *)key
{
    //handle target/action
    UIControlEvents event = [key UIControlEventsValue];
    if (event)
    {
        SEL selector = [value selectorValue];
        [self addTarget:[self SC_actionTarget] action:selector forControlEvents:event];
        return;
    }
    
    //handle setValue:forState:
    if ([key length] > 1)
    {
        NSString *name = key;
        UIControlState state = UIControlStateNormal;
        for (NSString *prefix in [key SC_controlStates])
        {
            if ([name hasPrefix:prefix])
            {
                state = [[key SC_controlStates][prefix] integerValue];
                name = [name substringFromIndex:[prefix length]];
                break;
            }
        }
        name = [[[name substringToIndex:1] uppercaseString] stringByAppendingString:[name substringFromIndex:1]];
        SEL selector = NSSelectorFromString([NSString stringWithFormat:@"set%@:forState:", name]);
        if ([self respondsToSelector:selector])
        {
            NSString *type = [self SC_typeNameForKey:[NSString stringWithFormat:@"current%@", name]];
            if (type) objc_msgSend(self, selector, [value SC_valueForTypeName:type], state);
            return;
        }
    }
    
    //default implementation
    [super setValueWithString:value forKey:key];
}

@end

@implementation UIButton (StringValues)

- (NSString *)SC_typeNameForKey:(NSString *)key
{
    static NSDictionary *types = nil;
    if (types == nil)
    {
        types = @{@"buttonType": @"UIButtonType",
                  @"contentEdgeInsets": @"UIEdgeInsets",
                  @"titleEdgeInsets": @"UIEdgeInsets",
                  @"imageEdgeInsets": @"UIEdgeInsets"};
    }
    return types[key] ?: [super SC_typeNameForKey:key];
}

@end

@implementation UITextField (StringValues)

- (NSString *)SC_typeNameForKey:(NSString *)key
{
    static NSDictionary *types = nil;
    if (types == nil)
    {
        types = @{@"textAlignment": @"NSTextAlignment",
                  @"borderStyle": @"UITextBorderStyle",
                  @"clearButtonMode": @"UITextFieldViewMode",
                  @"leftViewMode": @"UITextFieldViewMode",
                  @"rightViewMode": @"UITextFieldViewMode",};
    }
    return types[key] ?: [super SC_typeNameForKey:key];
}

@end

@implementation UIToolbar (StringValues)

- (NSString *)SC_typeNameForKey:(NSString *)key
{
    static NSDictionary *types = nil;
    if (types == nil)
    {
        types = @{@"barStyle": @"UIBarStyle"};
    }
    return types[key] ?: [super SC_typeNameForKey:key];
}

//TODO: work out system for setting property for state, style AND metrics

@end

@implementation UINavigationBar (StringValues)

- (NSString *)SC_typeNameForKey:(NSString *)key
{
    static NSDictionary *types = nil;
    if (types == nil)
    {
        types = @{@"barStyle": @"UIBarStyle"};
    }
    return types[key] ?: [super SC_typeNameForKey:key];
}

//TODO: work out system for setting property for state, style AND metrics

@end

@implementation UIBarItem (StringValues)

- (NSString *)SC_typeNameForKey:(NSString *)key
{
    static NSDictionary *types = nil;
    if (types == nil)
    {
        types = @{@"imageInsets": @"UIEdgeInsets",
                  @"landscapeImagePhoneInsets": @"UIEdgeInsets"};
    }
    return types[key] ?: [super SC_typeNameForKey:key];
}

@end

@implementation UIBarButtonItem (StringValues)

- (NSString *)SC_typeNameForKey:(NSString *)key
{
    static NSDictionary *types = nil;
    if (types == nil)
    {
        types = @{@"style": @"UIBarButtonItemStyle",
                  @"landscapeImagePhoneInsets": @"UIEdgeInsets"};
    }
    return types[key] ?: [super SC_typeNameForKey:key];
}

- (id)SC_actionTarget
{
    SCActionTarget *target = objc_getAssociatedObject(self, _cmd);
    if (!target)
    {
        target = [[SCActionTarget alloc] init];
        target.sender = self;
        objc_setAssociatedObject(self, _cmd, target, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return target;
}

- (void)SC_setActionWithString:(NSString *)string
{
    self.action = [string selectorValue];
    if (!self.target)
    {
        self.target = [self SC_actionTarget];
    }
}

//TODO: work out system for setting property for state, style AND metrics

@end

@implementation UITabBarItem (StringValues)

- (NSString *)SC_typeNameForKey:(NSString *)key
{
    static NSDictionary *types = nil;
    if (types == nil)
    {
        types = @{@"titlePositionAdjustment": @"UIOffset"};
    }
    return types[key] ?: [super SC_typeNameForKey:key];
}

- (void)SC_setFinishedSelectedImageWithString:(NSString *)string
{
    [self setFinishedSelectedImage:[string UIImageValue]
       withFinishedUnselectedImage:[self finishedUnselectedImage]];
}

- (void)SC_setFinishedUnselectedImageWithString:(NSString *)string
{
    [self setFinishedSelectedImage:[self finishedSelectedImage]
       withFinishedUnselectedImage:[string UIImageValue]];
}

@end

@implementation UIWebView (StringValues)

- (NSURL *)SC_baseURL
{
    return objc_getAssociatedObject(self, _cmd);
}

- (void)SC_setBaseURLWithString:(NSString *)string
{
    objc_setAssociatedObject(self, @selector(SC_baseURL), [string NSURLValue], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)SC_setRequestWithString:(NSString *)string
{
    [self loadRequest:[string SC_NSURLRequestValueRelativeToURL:[self SC_baseURL]]];
}

- (void)SC_setHTMLStringWithString:(NSString *)string
{
    [self loadHTMLString:string baseURL:[self SC_baseURL]];
}

@end

#endif