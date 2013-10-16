$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "service_base/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
	s.name = "service_base"
	s.version = ServiceBase::VERSION
	s.authors = ["PuzzleFlow Team"]
	s.email = ["support@puzzleflow.com"]
	s.homepage = "http://puzzleflow.com"
	s.summary = "The base components used by services' implementation."
	s.description = "This is a set of common tools used during implementation of PuzzleFlow services."

	s.files = Dir["{app,config,db,lib}/**/*"] + ["MIT-LICENSE", "Rakefile", "README.rdoc"]
	s.test_files = Dir["test/**/*"]

	s.add_dependency "rails", "3.2.12"
	s.add_dependency "bunny", "~> 0.10.8"
	s.add_dependency "dalli", "~> 2.6.4"
end
