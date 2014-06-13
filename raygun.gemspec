# -*- encoding: utf-8 -*-

File.expand_path('../lib', __FILE__).tap do |lib|
  $LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
end

require 'raygun/version'

Gem::Specification.new do |gem|
  gem.name          = "raygun-gl"
  gem.version       = Raygun::VERSION
  gem.authors       = ["Christian Nelson", "Jonah Williams", "Jason Wadsworth", "Michael Johnston"]
  gem.email         = ["lastobelus@gmail.com"]
  gem.description   = %q{Rails application generator}
  gem.summary       = %q{Generates and customizes Rails applications from prototype repos which can live either on github or on private gitlab instances.}
  gem.homepage      = "https://github.com/lastobelus/raygun-gl"
  gem.license       = 'MIT'

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map { |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
  gem.add_dependency "gitlab", "~> 3"
  gem.add_development_dependency "pry"
  gem.add_development_dependency "awesome_print"
end
