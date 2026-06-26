#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint sms_autodetect.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'sms_autodetect'
  s.version          = '1.1.1'
  s.summary          = 'Flutter plugin for SMS code autofill support.'
  s.description      = <<-DESC
Flutter plugin to provide SMS code auto-detect support and PIN code fields.
                       DESC
  s.homepage         = 'https://github.com/Yadav-Sunil/sms_autodetect'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'Sunil Yadav' => 'Yadav-Sunil' }
  s.source           = { :git => 'https://github.com/Yadav-Sunil/sms_autodetect.git', :tag => s.version.to_s }
  s.source_files = 'sms_autodetect/Sources/sms_autodetect/**/*.{h,m}'
  s.public_header_files = 'sms_autodetect/Sources/sms_autodetect/include/**/*.h'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
end
