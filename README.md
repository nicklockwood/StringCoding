[![Build Status](https://travis-ci.org/nicklockwood/StringCoding.svg)](https://travis-ci.org/nicklockwood/StringCoding)


Purpose
--------------

StringCoding is a simple library for Mac and iOS that supports setting object properties of any type using string values. It can automatically detect the property type and attempt to interpret the string as the right kind of value.

StringCoding is really handy for creating configuration files for quickly tweaking properties of your app without needing to recompile.

StringCoding is specialised towards configuring UIKit views and controls. A typical use case is the creation of plist or json "stylesheets" for configuring app appearance. This can be very useful for apps that have multiple themes or "skins".

Unlike other libraries, StringCoding does not add any additional styling properties to views. It is designed to only provide string coding access for existing properties and methods, not extend functionality. Because of the way it works however, it can automatically detect and support additional properties added via categories (see "Adding Support for Additional String Properties and Types" below). For example, if you use the ViewUtils library (https://github.com/nicklockwood/ViewUtils), which extends UIView with explicit detters for width, height, etc. the StringCoding will allow you to set those properties using strings without needing to add explicit support.

Check out the included UIConfig example to see some of StringCoding's capabilities in action.


Supported iOS & SDK Versions
-----------------------------

* Supported build target - iOS 8.0 / Mac OS 10.9 (Xcode 6.0, Apple LLVM compiler 6.0)
* Earliest supported deployment target - iOS 6.0 / Mac OS 10.7
* Earliest compatible deployment target - iOS 4.3 / Mac OS 10.6

NOTE: 'Supported' means that the library has been tested with this version. 'Compatible' means that the library should work on this iOS version (i.e. it doesn't rely on any unavailable SDK features) but is no longer being tested for compatibility and may require tweaking or bug fixes to run correctly.


ARC Compatibility
------------------

As of version 1.2, StringCoding requires ARC. If you wish to use StringCoding in a non-ARC project, just add the -fobjc-arc compiler flag to the StringCoding.m file. To do this, go to the Build Phases tab in your target settings, open the Compile Sources group, double-click StringCoding.m in the list and type -fobjc-arc into the popover.

If you wish to convert your whole project to ARC, comment out the #error line in StringCoding.m, then run the Edit > Refactor > Convert to Objective-C ARC... tool in Xcode and make sure all files that you wish to use ARC for (including StringCoding.m) are checked.


Installation
---------------

To use StringCoding, just drag the StringCoding.h and .m files into your project and add the QuartzCore framework. StringCoding also requires that you include either the UIKit or APPKit frameworks, and that whichever one you are using is included in the .pch file in your project. The StringCoding methods are implemented on existing classes using categories, so as long as you import the header into your class, the StringCoding methods will be available.


NSObject Extension Methods
----------------------------

StringCoding extends every object with the following additional methods:

    - (void)setValueWithString:(NSString *)value forKey:(NSString *)key;
    - (void)setValueWithString:(NSString *)value forKeyPath:(NSString *)keyPath;
    
These methods work like the standard KVC setValue:forKey: and setValue:forKeyPath: methods except that the value is always a string and will automatically be converted to the correct type, provided that the type is known. Attempting to set a property of an unknown type will throw an exception. This can be fixed on a per case basis by adding a specific string setter method (see below).

Note: By default, StringCoding swizzles `setValue:forKey:` and `setValue:forKeyPath:` to call the setStringValue equivalents when appropriate. This means that it is not neccesary for you to call setValueWithString: explicitly unless you have disabled swizzling using the SC_SWIZZLE_ENABLED macro (see swizzling note below).


NSString Extension Methods
----------------------------

StringCoding extends every NSString with the following additional methods:

    - (BOOL)isNumeric;
    
Returns YES if the value of the string can be interpreted as a number.
    
    - (Class)classValue;
    
Returns the class whose name matches the string, or nil if the class does not exist. Equivalent to the NSClassFromString() function.

    - (SEL)selectorValue;
    
Returns a selector matching the string. This can be used to call methods on objects, and is utilised by the target/action binding system for UIControls (see below).
    
    - (char)charValue;
    
Returns the char values of the string. The value is determined as follows: If the string is a single character, the ascii value of the character will be returned (the result for non-ascii characters is undefined). If the string is a multi-digit numeric value then that number will be returned (provided that it is in the range 10-127 or -1 to -128). If the string is a hex number preceeded by "0x" then it will be returned provided that it is in the range 0-127. Higher values will be treated as negative. If the string is a boolean value such as "yes" or "true" then a value of 1 or 0 will be returned.
    
    - (NSURL *)NSURLValue;
    
Returns the NSURL value of the string. If the path is an absolute file path then it will be returned as a file URL, otherwise it will be returned as an ordinary URL. If the URL is a relative path then the baseURL property will be set as the app bundle resource directory. If the string is empty then it will return nil.

    - (NSURL *)NSURLRequestValue;
    
Treats the string as an NSURL, using the same logic as for NSURLValue. The URL may optionally be preceeded by a REST method (GET, PUT, POST, DELETE, HEAD, OPTIONS) separated by a space. If the method is not included, it is assumed to be a GET request.
    
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
    - (NSLineBreakMode)NSLineBreakModeValue;

These methods return the NSTextAlignment and NSLineBreakMode values of the string, respectively. The string can contain either a short name like "left" or "justfied" or the fully-qualified name like "NSTextAlignmentLeft". The value is case-insensitive.


NSString Extension Methods (UIKit only)
----------------------------------------

    - (UIColor *)UIColorValue;
    
Returns a UIColor using the same logic as for CGColorRefValue.
    
    - (UIImage *)UIImageValue;
    
Returns a UIImage, treating the string as a file name, path or URL. You can optionally append one or two space-delimited floating point values representing stretchable image left and top caps respectively.
    
    - (UIFont *)UIFontValue;
    
Returns a UIFont using the same logic as for CGFontRefValue, with the additional feature that you can optionally specify the font size by adding a floating point value separatd by a space (e.g. "helvetica 17" or "bold 15"). If you do not specify a font size then the default system font size will be used (this will be 13 points on Mac OS, and 17 points on iOS).
    
    - (UIEdgeInsets)UIEdgeInsetsValue;
    - (UIOffset)UIOffsetValue;
    
Returns the appropriate struct type. The string can contain either space-delimited floating point values, or can be formatted using the appropriate NSStringFromX syntax, e.g. "{top,left,bottom,right}" (equivalent to the result of calling NSStringFromUIEdgeInsets()).
        
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
    
Returns the specified enum or bitmask value of the string. For enums, this should be a single value matching the full name of the suffix of the constant value (e.g. "UIViewContentModeScaleAspectFit" or just "scaleaspectfit").  Where appropriate some aliases have been provided for hard-to-remember constants, e.g. "fit" for "scaleaspectfit"). The value is case-insensitive. For bitmask-type values, you can specify multiple values separated by spaces. You can also use "none" or "all".
    
    
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


UIControl styling
--------------------

UIControl subclasses often have style properties that are associated to a particular UIControlState. For example, to set the title color to red for a UIButton, you would use:

    [button setTitleColor:[UIColor redColor] forState:UIControlStateNormal];

StringCoding supports this type of styling using pseudo properties. To set the title color for UIControlStateNormal, you can use either of the following:

    [control setValueWithString:@"red" forKey:@"titleColor"];
    [control setValueWithString:@"red" forKey:@"normalTitleColor"];
    
To set the color for the selected state, you would use:

    [control setValueWithString:@"red" forKey:@"selectedTitleColor"];

And so on. The key in this case *is* case sensitive. This is only a virtual property, not a real one, so you can't set it using:

    control.selectedTitleColor = [UIColor redColor]; //this won't work
    [control setSelectedTitleColor:[UIColor redColor]]; //nor this


UIControl target/action binding
--------------------------------

To bind an action to a control using a string, you can make use of some pseudo properties provided by StringCoding. For example, to bind a selector called "showAlert:" to the UIControlEventTouchUpInside, you can say:

    [control setValueWithString:@"alert:" forKey:@"touchupinside"];

As with other constants, the key is case insensitive and can use the fully qualified (e.g.. "UIControlEventTouchUpInside") or shorthand version. This is only a virtual property, not a real one, so you can't set it using:

    control.touchUpInside = @selector(alert:); //this won't work
    [control setTouchUpInside:@selector(alert:)]; //nor this

However, assuming you've not disabled swizzling, it can be set using `setValue:forKey:` or `setValue:forKeyPath:`, so this will work:

    [control setValue:@"alert:" forKey:@"touchupinside"];

If you've been paying attention you might wonder how to set the *target* for the action. The target is set as a special proxy class that will determine the target automatically from the responder chain at runtime, so the first containing UIResponder (i.e. UIView or UIViewController) in the chain that responds to the specified selector will receive the message. If the view hierarchy changes, the target will be recalculated.


Special Case Setters
---------------------------

In addition to the standard string setter extension behaviours, StringCoding also includes some special-case pseudo properties for UIKit classes that can be uses to set values using setValueWithString:forKey: 

    UITabBarItem
        finishedSelectedImage
        finishedUnselectedImage
        
These properties can be used to set the finished (i.e. post-processed) tab bar images.

    UIWebView
        request
        HTMLString
        baseURL
        
These properties can be used to load a specific request URL, HTML string or data object into a web view using a string setter. The optional baseURL is used as a relative value for any subsequent request, HTML or data values set.  


Adding Support for Additional String Properties and Types
--------------------------------------------------------------

StringCoding only supports a finite set of value types. To add support for additional types, use a category to extend NSString with a new value method of the form:

    - (<type>)<typeName>Value;

So for example to add support for a class called NSFoo you would add a method of the form:

    - (NSFoo *)NSFooValue;

To support Core Foundation object types, omit the "Ref", so for a type like CGFooRef, use:

    - (CGFooRef)CGFooValue;
    
Any property of this type on any object will now automatically be settable using a string value via the setValueWithString:forKey: method. If the property type is unknown then this won't work however. StringCoding will automatically detect and support properties added via categories or subclasses, however it may not always be able to determine the type.

For example, the contents property of CALayer is supposed to be an image, but is defined as an id, so StringCoder can't determine the type automatically. This also applies to properties that expect a constant value, as the type appears as integer or string.

To solve this, you can add a setter method via a category of the form:

    - (void)set<propertyName>asString:(NSString *)stringValue;
    
So in the case of the CALayer contents property, the method is defined as:

    - (void)setContentsAsString:(NSString *)stringValue;

The implementation treats the value as an image. The setValueWithString:forKey: method detects the presence of this method automatically and calls it instead of the default implementation.


Swizzling
-----------------

By default, StringCoding swizzles the `setValue:forKey:` and `setValue:forKeyPath:` methods to enable it to be used more easily (for example, this measn you can set objects by string value in Interface Builder). If you don't want this behaviour then don't panic, you can disable it by adding the following pre-compiler macro to your build settings:

    SC_SWIZZLE_ENABLED=0

Or if you prefer, add this to your prefix.pch file:

    #define SC_SWIZZLE_ENABLED 0


Release notes
------------------

Version 1.2.2

- Fixed imports for Xcode 6 
- Now complies with the -Weverything warning level

Version 1.2.1

- Added explicit function pointer casts for all obc_msgSend calls
- Now complies with the -Wextra warning level
- Added podspec

Version 1.2

- StringCoding now requires ARC. See README for details
- Renamed NSObject category methods setStringValue:forKey: and setStringValue:forKeyPath: to setValueWithString:forKey: and setValueWithString:forKeyPath:
- Fixed bug when handling Core Foundation object types
- Added NSURLRequestValue getter to NSString category
- Added NSNumberValue getter to NSString category
- Added additional special-case setters
- Smarter target/action binding
- Now handles actions for UIBarButtonItems

Version 1.1

- Now swizzles setValue:forKey: and setValue:forKeyPath: so string coding support works automatically. This makes it possible to set string values via Interface Builder, amongst other things
- Now supports target/action binding on UIControls via string (the string represents a selector that will automatically be sent to the first object in the responder chain that responds to it)
- Now supports setValue:forState: values on UIControls
- Added support for many UIKit constants and view/control types
- More robust type detection logic
- Added UIConfig example

Version 1.0

- Initial release