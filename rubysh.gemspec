# -*- encoding: utf-8 -*-
require File.expand_path('../lib/rubysh/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Greg Brockman"]
  gem.email         = ["gdb@gregbrockman.com"]
  gem.description   = "Rubysh: subprocesses made easy"
  gem.summary       = "Rubysh makes shelling out easy with a __sh__-like syntax layer for Ruby:

    irb -r rubysh
    >> command = Rubysh('echo', 'hello-from-Rubysh') | Rubysh('grep', '--color', 'Rubysh')
    >> command.run
    hello-from-Rubysh
    => Rubysh::Runner: echo hello-from-Rubysh | grep --color Rubysh (exitstatus: 0)"
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
