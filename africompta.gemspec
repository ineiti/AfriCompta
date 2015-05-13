Gem::Specification.new do |s|
  s.name = 'afri_compta'
  s.version = '1.9.8'
  s.date = '2015-05-13'
  s.summary = 'Africompta-module for QooxView'
  s.description = 'With this module you can have a simple accounting-system'
  s.authors = ['Linus Gasser']
  s.email = 'ineiti@linusetviviane.ch'

  s.files         = `git ls-files -z`.split("\x0")
  s.executables   = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  s.require_paths = ['lib']

  s.homepage =
      'https://github.com/ineiti/AfriCompta'
  s.license = 'GPLv3'
end
