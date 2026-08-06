#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Binds XElement's element classes to their tag names.
///
/// XElement splits implementations and registration across subspecs, and the
/// registration half cannot be depended on here — see the implementation file
/// for why. This stands in for it.
@interface LynxXElementRegistry : NSObject

/// Registers every XElement element whose class is actually linked into the
/// app. Idempotent, and safe to call when XElement is absent entirely.
///
/// Must run before the first `LynxView` is built.
+ (void)registerAvailableElements;

@end

NS_ASSUME_NONNULL_END
