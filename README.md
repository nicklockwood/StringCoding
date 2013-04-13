Purpose
--------------

StringCoding is a simple library for setting object properties of any type using string values. It can automatically detect the property type and attempt to interpret the string as the right kind of value.

StringCoding is really handy for creating configuration files for quickly tweaking properties of your app without needing to recompile.


Supported iOS & SDK Versions
-----------------------------

* Supported build target - iOS 6.1 / Mac OS 10.8 (Xcode 4.6, Apple LLVM compiler 4.2)
* Earliest supported deployment target - iOS 5.0 / Mac OS 10.7
* Earliest compatible deployment target - iOS 4.3 / Mac OS 10.6

NOTE: 'Supported' means that the library has been tested with this version. 'Compatible' means that the library should work on this iOS version (i.e. it doesn't rely on any unavailable SDK features) but is no longer being tested for compatibility and may require tweaking or bug fixes to run correctly.


ARC Compatibility
------------------

StringCoding works correctly with both ARC and non-ARC targets. There is no need to exclude StringCoding files from the ARC validation process, or to convert StringCoding using the ARC conversion tool.


Installation
---------------

To use StringCoding, just drag the StringCoding.h and .m files into your project and add the QuartzCore framework. StringCoding also requires that you include either the UIKit or APPKit frameworks, and that whichever one you are using is included in the .pch file in your project. The StringCoding methods are implemented on existing classes using categories, so as long as you import the header into your class, the StringCoding methods will be available.


NSObject Extension Methods
----------------------------

StringCoding extends every object with the following additional methods:

    - (void)setStringValue:(NSString *)value forKey:(NSString *)key;
    - (void)setStringValue:(NSString *)value forKeyPath:(NSString *)keyPath;
    
These methods work like the standard KVC setValue:forKey: and setValue:forKeyPath: methods except that the value is always a string and will automatically be converted to the correct type, provided that the type is known. Attempting to set a property of an unknown type will throw an exception. This can be fixed on a per case basis by adding a specific string setter method (see below).


NSString Extension Methods
----------------------------

StringCoding extends every NSString with the following additional methods:

    - (BOOL)isNumeric;
    
Returns YES if the value of the string can be interpreted as a number.
    
    - (Class)classValue;
    
Returns the class whose name matches the string, or nil if the class does not exist. Equivalent to the NSClassFromString() function.
    
    - (char)charValue;
    
Returns the char values of the string. The value is determined as follows: If the string is a single character, the ascii value of the character will be returned (the result for non-ascii characters is undefined). If the string is a multi-digit numeric value then that number will be returned (provided that it is in the range 10-127 or -1 to -128). If the string is a hex number preceeded by "0x" then it will be returned provided that it is in the range 0-127. Higher values will be treated as negative. If the string is a boolean value such as "yes" or "true" then a value of 1 or 0 will be returned.
    
    - (NSURL *)NSURLValue;
    
Returns the NSURL value of the string. If the path is an absolute file path then it will be returned as a file URL, otherwise it will be returned as an ordinary URL. If the URL is a relative path then the baseURL property will be set as the app bundle resource directory. If the string is empty then it will return nil.
    
    - (CGPoint)CGPointValue;
    
Returns the CGPoint value of the string. The string can contain either a pair of space-delimited floating point values, or can be formatted as "{x,y}" (equivalent to the result of calling NSStringFromCGPoint()).
    
    - (CGSize)CGSizeValue;
    
Returns the CGSize value of the string. The string can contain either a pair of space-delimited floating point values, or can be formatted as "{width,height}" (equivalent to the result of calling NSStringFromCGSize()).
    
    - (CGRect)CGRectValue;
    
Returns the CGPoint value of the string. The string can contain either four space-delimited floating point values, or can be formatted as "{{x,y},{width,height}}" (equivalent to the result of calling NSStringFromCGRect()).
    
    - (CGColorRef)CGColorValue;
    
Returns a CGColorRef whose value is determined according to the following algorithm: First if the string is a name that matches one of the standard UIColor/NSColor values (e.g. black or blackColor - case insensitive) then it will return that color. If the string is a URL or file path for an image then it will be treated as a pattern image. Otherwise, a color will be accepted in the form of "rgb(r,g,b)", "rgba(r,g,b,a)" or a 6 or 8 chracter hex value with or without a leading # (e.g. "#ff0000" for red).
    
    - (CGImageRef)CGImageValue;
    
Returns a CGImageRef. The string is interpreted as an image file name, path or URL.
    
    - (CGFontRef)CGFontValue;
    
Returns a CGFontRef for a font chosen according to the following criteria: If the string matches a font name then it will be returned. If the value is "bold" or "italic" then the appropriate bold or italic system font variant will be returned. Any other value will return the default system font.

    - (NSTextAlignment)NSTextAlignmentValue;
    
Returns the NSTextAlignment value of the string. The string can contain either a short name like "left" or "justfied" or the fully-qualified name like "NSTextAlignmentLeft". The value is case-insensitive. Legacy UITextAlignment constant names are also supported.


NSString Extension Methods (UIKit only)
----------------------------------------

    - (UIColor *)UIColorValue;
    
Returns a UIColor using the same logic as for CGColorRefValue.
    
    - (UIImage *)UIImageValue;
    
Returns a UIImage, treating the string as a file name, path or URL. You can optionally append one or two space-delimited floating point values representing stretchable image left and top caps respectively.
    
    - (UIFont *)UIFontValue;
    
Returns a UIFont using the same logic as for CGFontRefValue, with the additional feature that you can optionally specify the font size by adding a floating point value separatd by a space (e.g. "helvetica 17" or "bold 15"). If you do not specify a font size then the default system font size will be used.
    
    - (UIEdgeInsets)UIEdgeInsetsValue;
    
Returns the UIEdgeInsets value of the string. The string can contain either four space-delimited floating point values, or can be formatted as "{top,left,bottom,right}" (equivalent to the result of calling NSStringFromUIEdgeInsets()).
        
    - (UIViewContentMode)UIViewContentModeValue;
    
Returns the UIViewContentModeValue value of the string. The string can contain either a short name like "scaletofill" or the fully-qualified name like "UIViewContentModeScaleAspectFit". The value is case-insensitive.
    
    
NSString Extension Methods (AppKit only)
----------------------------------------

    - (NSPoint)NSPointValue;
    - (NSSize)NSSizeValue;
    - (NSRect)NSRectValue;
    
These behave exactly the same as the CGPoint/Size/RectValue equivalents.
    
    - (NSColor *)NSColorValue;
    
Returns an NSColor using the same logic as for CGColorRefValue.
    
    - (NSImage *)NSImageValue;
    
Returns an NSImage, treating the string as a file name, path or URL.
    
    - (NSFont *)NSFontValue;
    
Returns an NSFont using the same logic as for CGFontRefValue, with the additional feature that you can optionally specify the font size by adding a floating point value separatd by a space (e.g. "helvetica 17" or "bold 15"). If you do not specify a font size then the default system font size will be used.


Adding Support for Additional String Properties and Types
--------------------------------------------------------------

To add support for additional value types, use a category to extend NSString with a new value method of the form:

    - (<type>)<typeName>Value;

So for example to add support for a class called NSFoo you would add a method of the form:

    - (NSFoo *)NSFooValue;

To support Core Foundation object types, omit the "Ref", so for a type like CGFooRef, use:

    - (CGFooRef)CGFooValue;
    
Any property of this type on any object will now automatically be settable using a string value via the setStringValue:forKey: method. If the property type is unknown then this won't work however. For example, the contents property of CALayer is supposed to be an image, but is defined as an id, so StringCoder can't determine the type automatically. This also applies to properties that expect a constant value, as the type appears as integer or string.

To solve this, you can add a setter method via a category of the form:

    - (void)set<propertyName>asString:(NSString *)stringValue;
    
So in the case of the CALayer contents property, the method is defined as:

    - (void)setContentsAsString:(NSString *)stringValue;

The implementation treats the value as an image. The setStringValue:forKey: method detects the presence of this method automatically and calls it instead of the default implementation.