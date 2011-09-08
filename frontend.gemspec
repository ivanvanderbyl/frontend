# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "frontend/version"

Gem::Specification.new do |s|
  s.name        = "frontend"
  s.version     = Frontend::VERSION
  s.authors     = ["Ivan Vanderbyl"]
  s.email       = ["ivanvanderbyl@me.com"]
  s.homepage    = "http://github.com/ivanvanderbyl/frontend"
  s.summary     = %q{A Rails 3.1 engine which provides Javascript libraries and CSS frameworks for rapidly prototyping advanced frontends}
  s.description = %q{Includes: jQuery, Backbone, Backbone.localStorage, Backrub, Handlebars, Twitter Bootstrap (SCSS) and more.}

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  # s.add_development_dependency "rspec"
  s.add_runtime_dependency "rails", '~> 3.1.0'
  s.add_runtime_dependency "rails-backbone", '~> 0.5.3'
end
