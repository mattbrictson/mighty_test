require "test_helper"

class FailingTest < Minitest::Test
  def test_assertion_fails
    assert_equal "foo", "bar"
  end
end
