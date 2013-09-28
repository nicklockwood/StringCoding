Pod::Spec.new do |s|
  s.name     = 'StringCoding'
  s.version  = '1.2.1'
  s.license  = 'zlib'
  s.summary  = 'Set object properties of any type using string values.'
  s.homepage = 'https://github.com/nicklockwood/StringCoding'
  s.authors  = 'Nick Lockwood'
  s.source   = { :git => 'https://github.com/nicklockwood/StringCoding.git', :tag => '1.2.1' }
  s.source_files = 'StringCoding'
  s.requires_arc = true
  s.ios.deployment_target = '4.3'
  s.osx.deployment_target = '10.6'
end
