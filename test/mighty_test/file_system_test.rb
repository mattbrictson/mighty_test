require "test_helper"

module MightyTest
  class FileSystemTest < Minitest::Test
    include FixturesPath

    def test_find_matching_test_file_returns_nil_for_nil_path
      assert_nil find_matching_test_file(nil)
    end

    def test_find_matching_test_file_returns_nil_for_non_existent_path
      assert_nil find_matching_test_file("path/to/nowhere.rb")
    end

    def test_find_matching_test_file_returns_nil_for_directory_path
      assert_nil find_matching_test_file("lib/example", in: fixtures_path.join("example_project"))
    end

    def test_find_matching_test_file_returns_nil_for_path_with_no_corresponding_test
      assert_nil find_matching_test_file("lib/example/version.rb", in: fixtures_path.join("example_project"))
    end

    def test_find_matching_test_file_returns_nil_for_a_test_support_file
      assert_nil find_matching_test_file("test/test_helper.rb", in: fixtures_path.join("example_project"))
    end

    def test_find_matching_test_file_returns_argument_if_it_is_already_a_test
      test_path = find_matching_test_file("test/example_test.rb", in: fixtures_path.join("example_project"))
      assert_equal("test/example_test.rb", test_path)
    end

    def test_find_matching_test_file_returns_matching_test_given_an_implementation_path_in_a_gem_project
      test_path = find_matching_test_file("lib/example.rb", in: fixtures_path.join("example_project"))
      assert_equal("test/example_test.rb", test_path)
    end

    def test_find_matching_test_file_returns_matching_test_given_a_model_path_in_a_rails_project
      test_path = find_matching_test_file("app/models/user.rb", in: fixtures_path.join("rails_project"))
      assert_equal("test/models/user_test.rb", test_path)
    end

    private

    def find_matching_test_file(path, in: ".")
      Dir.chdir(binding.local_variable_get(:in)) do
        FileSystem.new.find_matching_test_file(path)
      end
    end
  end
end
