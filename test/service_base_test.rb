require 'test_helper'

class ServiceBaseTest < ActiveSupport::TestCase
  test "truth" do
    assert_kind_of Module, ServiceBase
  end
end
