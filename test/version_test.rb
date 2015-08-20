require_relative 'test_helper'

class VersionTest < Minitest::Test
  def test_version_match
    spec = Gem::Specification::load(File.expand_path('../../tochtli.gemspec', __FILE__))
    assert_equal Tochtli::VERSION, spec.version.to_s, "Gem version mismatch. Run: 'rake gemspec'"
  end
end