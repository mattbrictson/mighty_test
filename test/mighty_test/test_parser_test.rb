require "test_helper"

module MightyTest
  class TestParserTest < Minitest::Test
    include FixturesPath

    def test_returns_nil_if_no_test_found
      name = test_name_at_line(fixtures_path.join("example_project/test/example_test.rb"), 3)
      assert_nil name
    end

    def test_finds_traditional_test_name_by_line_number
      name = test_name_at_line(fixtures_path.join("example_project/test/example_test.rb"), 5)
      assert_equal "test_that_it_has_a_version_number", name
    end

    def test_finds_traditional_test_name_by_line_number_even_with_focus
      name = test_name_at_line(fixtures_path.join("example_project/test/focused_test.rb"), 5)
      assert_equal "test_this_test_is_run", name
    end

    def test_finds_active_support_test_name_by_line_number
      name = test_name_at_line(fixtures_path.join("active_support_test.rb"), 5)
      assert_equal "test_it's_important", name
    end

    def test_finds_single_quoted_active_support_test_name_by_line_number
      name = test_name_at_line(fixtures_path.join("active_support_test.rb"), 9)
      assert_equal 'test_it_does_something_"interesting"', name
    end

    private

    def test_name_at_line(path, line_number)
      TestParser.new(path).test_name_at_line(line_number)
    end
  end
end
