#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Makes a scrolled-past `<image>` request actually stop.
///
/// Lynx asks the image service for a cancel block with every request and runs
/// it when the `<image>` moves on — a recycled list cell gets a new `src`, the
/// same `src` is re-requested, the element goes away. The stock
/// `LynxService/Image` (4.0.0) hands back a block that cancels
/// `imageUI.customImageRequest`, which it never assigns, so nothing stops: in a
/// long image list every cell flung past keeps downloading and decoding behind
/// the ones on screen.
///
/// Installed, the service's `loadNewImageFromURL:…` keeps the SDWebImage
/// operation it starts and the returned block cancels it. A cancelled request
/// never reports back — Lynx would otherwise read the cancellation as an error
/// for a `src` that is being re-requested. Requests still running when their
/// `LynxUIImage` is deallocated are cancelled too (Lynx only does that itself
/// behind `enable_image_cancel_request`, which a host cannot set from here).
///
/// Off by default; `setEnabled:` decides per request, so turning it off sends
/// the next request through the stock path unchanged.
@interface LynxImageRequestCancellation : NSObject

/// Whether requests started from now on can be cancelled.
@property(class, atomic, assign, getter=isEnabled) BOOL enabled;

/// Swaps in the cancellable loader. Idempotent. A no-op when the stock image
/// service is not linked or its loader has a different shape.
+ (void)install;

/// Whether `install` found the stock loader and replaced it.
@property(class, atomic, readonly, getter=isInstalled) BOOL installed;

@end

NS_ASSUME_NONNULL_END
