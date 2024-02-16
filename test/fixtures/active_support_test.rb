require "rails_helper"

class ActiveSupportTest < ActiveSupport::TestCase
  test "it's important" do # Trailing comment OK
    assert true # rubocop:disable Minitest/UselessAssertion
  end

  test 'it does something "interesting"' do
    assert true # rubocop:disable Minitest/UselessAssertion
  end
end
