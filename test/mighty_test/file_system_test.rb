require "test_helper"

module MightyTest
  class FileSystemTest < Minitest::Test
    include FixturesPath

    def test_find_matching_test_path_returns_nil_for_nil_path
      assert_nil find_matching_test_path(nil)
    end

    def test_find_matching_test_path_returns_nil_for_non_existent_path
      assert_nil find_matching_test_path("path/to/nowhere.rb")
    end

    def test_find_matching_test_path_returns_nil_for_directory_path
      assert_nil find_matching_test_path("lib/example", in: fixtures_path.join("example_project"))
    end

    def test_find_matching_test_path_returns_nil_for_path_with_no_corresponding_test
      assert_nil find_matching_test_path("lib/example/version.rb", in: fixtures_path.join("example_project"))
    end

    def test_find_matching_test_path_returns_nil_for_a_test_support_file
      assert_nil find_matching_test_path("test/test_helper.rb", in: fixtures_path.join("example_project"))
    end

    def test_find_matching_test_path_returns_argument_if_it_is_already_a_test
      test_path = find_matching_test_path("test/example_test.rb", in: fixtures_path.join("example_project"))
      assert_equal("test/example_test.rb", test_path)
    end

    def test_find_matching_test_path_returns_matching_test_given_an_implementation_path_in_a_gem_project
      test_path = find_matching_test_path("lib/example.rb", in: fixtures_path.join("example_project"))
      assert_equal("test/example_test.rb", test_path)
    end

    def test_find_matching_test_path_returns_matching_test_given_a_model_path_in_a_rails_project
      test_path = find_matching_test_path("app/models/user.rb", in: fixtures_path.join("rails_project"))
      assert_equal("test/models/user_test.rb", test_path)
    end

    def test_find_test_paths_looks_in_test_directory_by_default
      test_paths = find_test_paths(in: fixtures_path.join("rails_project"))

      assert_equal(
        %w[
          test/helpers/users_helper_test.rb
          test/models/account_test.rb
          test/models/user_test.rb
          test/system/users_system_test.rb
        ],
        test_paths.sort
      )
    end

    def test_find_test_paths_returns_empty_array_if_given_non_existent_path
      test_paths = find_test_paths("path/to/nowhere", in: fixtures_path.join("rails_project"))

      assert_empty(test_paths)
    end

    def test_find_test_paths_returns_test_files_in_specific_directory
      test_paths = find_test_paths("test/models", in: fixtures_path.join("rails_project"))

      assert_equal(
        %w[
          test/models/account_test.rb
          test/models/user_test.rb
        ],
        test_paths.sort
      )
    end

    def test_find_new_and_changed_paths_returns_empty_array_if_git_exits_with_error
      status = Minitest::Mock.new
      status.expect(:success?, false)

      paths = Open3.stub(:capture3, ["", "oh no!", status]) do
        FileSystem.new.find_new_and_changed_paths
      end

      assert_empty paths
    end

    def test_find_new_and_changed_paths_returns_empty_array_if_system_call_fails
      paths = Open3.stub(:capture3, ->(*) { raise SystemCallError, "oh no!" }) do
        FileSystem.new.find_new_and_changed_paths
      end

      assert_empty paths
    end

    def test_find_new_and_changed_paths_returns_array_based_on_git_output
      git_output = <<~OUT
        lib/mighty_test/file_system.rb
        test/mighty_test/file_system_test.rb
      OUT

      status = Minitest::Mock.new
      status.expect(:success?, true)

      paths = Open3.stub(:capture3, [git_output, "", status]) do
        FileSystem.new.find_new_and_changed_paths
      end

      assert_equal(
        %w[
          lib/mighty_test/file_system.rb
          test/mighty_test/file_system_test.rb
        ],
        paths
      )
    end

    private

    def find_matching_test_path(path, in: ".")
      Dir.chdir(binding.local_variable_get(:in)) do
        FileSystem.new.find_matching_test_path(path)
      end
    end

    def find_test_paths(*path, in: ".")
      Dir.chdir(binding.local_variable_get(:in)) do
        FileSystem.new.find_test_paths(*path)
      end
    end
  end
end
