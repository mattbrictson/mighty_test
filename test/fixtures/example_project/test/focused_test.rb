require "test_helper"

class FocusedTest < Minitest::Test
  focus def test_this_test_is_run # rubocop:disable Minitest/Focus
    assert true # rubocop:disable Minitest/UselessAssertion
  end

  def test_this_test_is_not_run
    refute true # rubocop:disable Minitest/UselessAssertion
  end
end
