// Registers XElement's UI classes with Lynx.
//
// XElement ships the element implementations (`LynxUIInput`, `LynxUISVG`, ...)
// in one set of subspecs and the registration for them in another —
// `XElement/Behavior`, whose `LynxUI*AutoRegistry.m` files are what actually
// bind a class to a tag name. Depending on that subspec is not an option here:
// it pulls `XElement/Markdown`, which pulls the statically linked
// `ServalMarkdown`/`LynxTextra`, and CocoaPods rejects static binaries under
// the `use_frameworks!` that every Flutter Podfile declares:
//
//   [!] The 'Pods-Runner' target has transitive dependencies that include
//       statically linked binaries: (ServalMarkdown and LynxTextra)
//
// Without registration the classes link but are unreachable — a template using
// <input> compiles, renders an empty box, and never takes focus, which is the
// exact symptom this file exists to fix.
//
// So the registration is done here instead, using the same
// `LynxComponentRegistry` calls the upstream macros expand to. Classes are
// looked up by name so that a subspec the host app chose not to include simply
// registers nothing rather than failing to link.

#import "LynxXElementRegistry.h"

#import <Lynx/LynxComponentRegistry.h>

/// tag name -> (UI class, shadow node class). A nil shadow node means the
/// element does not have one; `<markdown>` is deliberately absent.
static NSDictionary<NSString *, NSArray<NSString *> *> *LynxXElementClassMap(void) {
  return @{
    @"input" : @[ @"LynxUIInput", @"LynxUIInputShadowNode" ],
    @"textarea" : @[ @"LynxUITextArea", @"LynxUITextAreaShadowNode" ],
    @"svg" : @[ @"LynxUISVG" ],
    @"overlay" : @[ @"LynxUIOverlay", @"LynxUIOverlayShadowNode" ],
    @"blur-view" : @[ @"LynxUIBlurView" ],
    @"refresh" : @[ @"LynxUIRefresh", @"LynxUIRefreshShadowNode" ],
    @"refresh-header" : @[ @"LynxUIRefreshHeader" ],
    @"viewpager" : @[ @"LynxUIViewPager" ],
    @"viewpager-item" : @[ @"LynxUIViewPagerItem" ],
    @"webview" : @[ @"LynxUIWebView" ],
    @"scroll-coordinator" : @[ @"LynxUIScrollCoordinator" ],
    @"scroll-coordinator-header" : @[ @"LynxUIScrollCoordinatorHeader" ],
    @"scroll-coordinator-slot" : @[ @"LynxUIScrollCoordinatorSlot" ],
    @"scroll-coordinator-slot-drag" : @[ @"LynxUIScrollCoordinatorSlotDrag" ],
    @"scroll-coordinator-toolbar" : @[ @"LynxUIScrollCoordinatorToolbar" ],
  };
}

@implementation LynxXElementRegistry

/// Runs once, before the first `LynxView` is built — see `LynxViewPlugin`.
///
/// Registering the same name twice is harmless (Lynx replaces the entry), but
/// the guard keeps it to a single pass regardless of how many views are made.
+ (void)registerAvailableElements {
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    [LynxXElementClassMap()
        enumerateKeysAndObjectsUsingBlock:^(NSString *name, NSArray<NSString *> *classNames,
                                            __unused BOOL *stop) {
          Class uiClass = NSClassFromString(classNames.firstObject);
          if (uiClass == Nil) {
            // The subspec providing this element was not linked in. Nothing to
            // register, and nothing to complain about.
            return;
          }
          [LynxComponentRegistry registerUI:uiClass withName:name];

          if (classNames.count > 1) {
            Class shadowClass = NSClassFromString(classNames[1]);
            if (shadowClass != Nil) {
              [LynxComponentRegistry registerShadowNode:shadowClass withName:name];
            }
          }
        }];
  });
}

@end
