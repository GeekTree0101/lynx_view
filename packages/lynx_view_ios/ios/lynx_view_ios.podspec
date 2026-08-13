#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint lynx_view_ios.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'lynx_view_ios'
  s.version          = '1.0.0'
  s.summary          = 'iOS implementation of the lynx_view plugin.'
  s.description      = <<-DESC
Wraps LynxJS's native LynxView as a Flutter PlatformView (iOS side).
                       DESC
  s.homepage         = 'https://github.com/GeekTree0101/lynx_view'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.dependency 'Lynx', '4.0.0'
  s.dependency 'PrimJS', '4.0.0'
  # XElement — the extended element library. The core Lynx pod registers only
  # 13 UI elements; without this, a template using <input>, <svg>, <overlay>
  # and friends renders nothing at all.
  #
  # Subspecs rather than the umbrella pod on purpose: XElement/Markdown pulls
  # ServalMarkdown, which pulls the statically linked LynxTextra, and CocoaPods
  # refuses that under the `use_frameworks!` every Flutter Podfile declares:
  #
  #   [!] The 'Pods-Runner' target has transitive dependencies that include
  #       statically linked binaries: (ServalMarkdown and LynxTextra)
  #
  # The catch is that the element subspecs ship the classes but not the
  # registration — every LynxUI*AutoRegistry.m lives in XElement/Behavior,
  # which depends on Markdown and so cannot be pulled in either. Without them
  # the classes are linked, dead, and unreachable: <input> compiles, renders
  # nothing, and never takes focus.
  #
  # So the registration is done in-package instead, minus the Markdown one —
  # see Classes/LynxXElementRegistry.m, which the plugin runs before it builds
  # its first LynxView.
  s.dependency 'XElement/Input', '4.0.0'
  s.dependency 'XElement/BlurView', '4.0.0'
  s.dependency 'XElement/Overlay', '4.0.0'
  s.dependency 'XElement/ScrollCoordinator', '4.0.0'
  s.dependency 'XElement/ViewPager', '4.0.0'
  s.dependency 'XElement/WebView', '4.0.0'
  s.dependency 'XElement/SVG', '4.0.0'
  s.dependency 'XElement/Refresh', '4.0.0'
  # Image service — Lynx's <image> does not fetch or decode anything by
  # itself; it delegates to a registered image service, and without one
  # remote sources silently render nothing. This subspec (SDWebImage-backed,
  # versions pinned by the subspec itself) self-registers at load via the
  # LynxServiceRegister macro in LynxImageService.m, so no registration code
  # is needed here — unlike XElement, whose registry lives in a subspec we
  # cannot pull (see above).
  s.dependency 'LynxService/Image', '4.0.0'
  # Lynx itself supports iOS 10+, but Flutter's own engine requires 12.0+ —
  # that's the binding floor here, not Lynx's.
  s.platform = :ios, '12.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'lynx_view_ios_privacy' => ['Resources/PrivacyInfo.xcprivacy']}
end
