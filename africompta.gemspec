Gem::Specification.new do |s|
  s.name = 'africompta'
  s.version = '1.9.9'
  s.date = '2015-05-13'
  s.summary = 'Africompta-module for QooxView'
  s.description = 'With this module you can have a simple accounting-system.
It is based on http://github.com/ineiti/QooxView and adds Entities to handle
accounts and movements. For the standalone counterpart (which uses the same database),
see http://github.com/ineiti/AfriCompta_client .'
  s.authors = ['Linus Gasser']
  s.email = 'ineiti@linusetviviane.ch'

  s.files         = `git ls-files -z`.split("\x0")
  s.executables   = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  s.require_paths = ['lib']

  s.homepage =
      'https://github.com/ineiti/AfriCompta'
  s.license = 'GPLv3'

  s.add_dependency 'qooxview', '1.9.9'
end
