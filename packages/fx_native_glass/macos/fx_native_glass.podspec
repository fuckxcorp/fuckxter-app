Pod::Spec.new do |s|
  s.name = 'fx_native_glass'
  s.version = '0.0.1'
  s.summary = 'Native Liquid Glass surfaces for FuckXter.'
  s.description = s.summary
  s.homepage = 'https://github.com/fuckxcorp/fuckxter-app'
  s.license = { :type => 'MoPL', :file => '../LICENSE' }
  s.author = { 'FuckXter' => 'https://github.com/fuckxcorp' }
  s.source = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'FlutterMacOS'
  s.platform = :osx, '10.15'
  s.swift_version = '5.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
