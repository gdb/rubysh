# -*- encoding: utf-8 -*-
require File.expand_path('../lib/rubysh/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Greg Brockman"]
  gem.email         = ["gdb@gregbrockman.com"]
  gem.description   = %q{TODO: Write a gem description}
  gem.summary       = %q{TODO: Write a gem summary}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "rubysh"
  gem.require_paths = ["lib"]
  gem.version       = Rubysh::VERSION

  gem.add_development_dependency 'minitest', '3.1.0'
  gem.add_development_dependency 'mocha'
end
