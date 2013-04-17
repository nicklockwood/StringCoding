Version 1.1

- Now swizzles setValue:forKey: and setValue:forKeyPath: so string coding support works automatically. This makes it possible to set string values via Interface Builder, amongst other things
- Now supports target/action binding on UIControls via string (the string represents a selector that will automatically be sent to the first object in the responder chain that responds to it)
- Now supports setValue:forState: values on UIControls
- Added support for many UIKit constants and view/control types
- More robust type detection logic
- Added UIConfig example

Version 1.0

- Initial release