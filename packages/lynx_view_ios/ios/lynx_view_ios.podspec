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
