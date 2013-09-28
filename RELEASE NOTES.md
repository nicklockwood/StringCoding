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