# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'bliss/version'

Gem::Specification.new do |spec|
  spec.name          = "bliss"
  spec.version       = Bliss::VERSION
  spec.authors       = ["Fernando Alonso"]
  spec.email         = ["krakatoa1987@gmail.com"]
  spec.description   = %q{streamed xml parsing tool}
  spec.summary       = %q{streamed xml parsing tool}
  spec.homepage      = "http://github.com/krakatoa/bliss"
  spec.license       = "MIT"
  spec.extra_rdoc_files = [
    "LICENSE.txt",
    "README.rdoc"
  ]

  spec.files         = `git ls-files`.split($/)
  spec.test_files    = spec.files.grep(%r{^(test)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "nokogiri", ">= 1.5.5"
  spec.add_runtime_dependency "rubyzip", ">= 0.9.9", "< 2.4.0"
  spec.add_runtime_dependency "eventmachine", "= 1.0.0.rc.4"
  spec.add_runtime_dependency "em-http-request", ">= 1.0.2"

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec", "~> 2.11.0"
  spec.add_development_dependency "simplecov", ">= 0"
  spec.add_development_dependency "guard"
  spec.add_development_dependency "guard-rspec"
  spec.add_development_dependency "rb-inotify"
  spec.add_development_dependency "rb-fsevent"
  spec.add_development_dependency "rb-fchange"

end
