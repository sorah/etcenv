# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'etcenv/version'

Gem::Specification.new do |spec|
  spec.name          = "etcenv"
  spec.version       = Etcenv::VERSION
  spec.authors       = ["Shota Fukumori (sora_h)"]
  spec.email         = ["sorah@cookpad.com"]

  spec.summary       = %q{Dump etcd keys into dotenv file or docker env file}
  spec.homepage      = "https://github.com/sorah/etcenv"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "bin"
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec"

  spec.add_dependency "etcd", ">= 0.3.0"
  spec.add_dependency "etcd-etcvault"
end
