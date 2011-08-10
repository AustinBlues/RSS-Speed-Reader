# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "rss_speed_reader/version"

Gem::Specification.new do |s|
  s.name        = "rss_speed_reader"
  s.version     = RssSpeedReader::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Jeffrey L. Taylor"]
  s.email       = ["jeff.taylor@ieee.org"]
  s.homepage    = ""
  s.summary     = %q{Fast RSS parser}
  s.description = %q{Fast parsing of an RSS file using libxml-ruby wrapper around libxml2.}
  s.add_dependency('libxml-ruby', '~> 1.1.0')
#  s.add_development_dependency('test-unit')

  s.rubyforge_project = "rss_speed_reader"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
