require "test_helper"

module MightyTest
  class CLITest < Minitest::Test
    include FixturesPath

    def test_help_flag_prints_usage_and_minitest_options
      result = cli_run(argv: ["--help"])

      assert_includes(result.stdout, "Usage: mt")
      assert_includes(result.stdout, "minitest options:")
    end

    def test_help_flag_takes_precedence_over_other_flags
      result = cli_run(argv: %w[--version --help])

      assert_includes(result.stdout, "Usage: mt")
    end

    def test_help_flag_doesnt_describe_help_twice
      result = cli_run(argv: ["--help"])

      assert_equal(1, result.stdout.lines.grep(/^\s*-h\b/).length)
    end

    def test_version_flag_prints_version
      result = cli_run(argv: ["--version"])

      assert_equal(VERSION, result.stdout.chomp)
    end

    def test_with_no_args_runs_all_tests_in_the_test_directory_excluding_slow_ones
      with_fake_minitest_runner do |runner, executed_tests|
        cli_run(argv: [], chdir: fixtures_path.join("rails_project"), runner:)

        assert_equal(
          %w[
            test/helpers/users_helper_test.rb
            test/models/account_test.rb
            test/models/user_test.rb
          ],
          executed_tests.sort
        )
      end
    end

    def test_with_all_flag_runs_all_tests_in_the_test_directory_including_slow_ones
      with_fake_minitest_runner do |runner, executed_tests|
        cli_run(argv: ["--all"], chdir: fixtures_path.join("rails_project"), runner:)

        assert_equal(
          %w[
            test/helpers/users_helper_test.rb
            test/models/account_test.rb
            test/models/user_test.rb
            test/system/users_system_test.rb
          ],
          executed_tests.sort
        )
      end
    end

    def test_with_ci_env_runs_all_tests_in_the_test_directory_including_slow_ones
      with_fake_minitest_runner do |runner, executed_tests|
        cli_run(argv: [], env: { "CI" => "1" }, chdir: fixtures_path.join("rails_project"), runner:)

        assert_equal(
          %w[
            test/helpers/users_helper_test.rb
            test/models/account_test.rb
            test/models/user_test.rb
            test/system/users_system_test.rb
          ],
          executed_tests.sort
        )
      end
    end

    def test_with_a_directory_arg_runs_all_test_files_in_that_directory
      with_fake_minitest_runner do |runner, executed_tests|
        cli_run(argv: ["test/models"], chdir: fixtures_path.join("rails_project"), runner:)

        assert_equal(
          %w[
            test/models/account_test.rb
            test/models/user_test.rb
          ],
          executed_tests.sort
        )
      end
    end

    def test_with_a_mixture_of_file_and_directory_args_runs_all_matching_tests
      with_fake_minitest_runner do |runner, executed_tests|
        cli_run(argv: %w[test/system test/models/user_test.rb], chdir: fixtures_path.join("rails_project"), runner:)

        assert_equal(
          %w[
            test/models/user_test.rb
            test/system/users_system_test.rb
          ],
          executed_tests.sort
        )
      end
    end

    def test_with_explict_file_args_runs_those_files_regardless_of_whether_they_appear_to_be_tests
      with_fake_minitest_runner do |runner, executed_tests|
        cli_run(argv: ["app/models/user.rb"], chdir: fixtures_path.join("rails_project"), runner:)

        assert_equal(
          %w[
            app/models/user.rb
          ],
          executed_tests.sort
        )
      end
    end

    def test_with_directory_args_only_runs_files_that_appear_to_be_tests
      with_fake_minitest_runner do |runner, executed_tests|
        cli_run(argv: ["app/models"], chdir: fixtures_path.join("rails_project"), runner:)

        assert_empty(executed_tests)
      end
    end

    def test_with_non_existent_path_raises_an_error
      error = assert_raises(ArgumentError) do
        cli_run(argv: ["test/models/non_existent_test.rb"], chdir: fixtures_path.join("rails_project"))
      end

      assert_includes(error.message, "test/models/non_existent_test.rb does not exist")
    end

    def test_divides_tests_into_shards
      all = with_fake_minitest_runner do |runner, executed_tests|
        cli_run(argv: [], chdir: fixtures_path.join("rails_project"), runner:)
        executed_tests
      end

      shards = %w[1/2 2/2].map do |shard|
        with_fake_minitest_runner do |runner, executed_tests|
          cli_run(argv: ["--shard", shard], chdir: fixtures_path.join("rails_project"), runner:)
          executed_tests
        end
      end

      shards.each do |shard|
        refute_empty shard
      end

      assert_equal all.length, shards.sum(&:length)
    end

    def test_w_flag_enables_ruby_warnings
      orig_verbose = $VERBOSE
      $VERBOSE = false

      with_fake_minitest_runner do |runner, executed_tests|
        cli_run(argv: %w[-w app/models/user.rb], chdir: fixtures_path.join("rails_project"), runner:)

        assert_equal(%w[app/models/user.rb], executed_tests)
        assert($VERBOSE)
      end
    ensure
      $VERBOSE = orig_verbose
    end

    def test_w_flag_is_passed_through_to_watcher
      new_mock_watcher = lambda do |extra_args:|
        assert_equal(["-w"], extra_args)

        mock = Minitest::Mock.new
        mock.expect(:run, nil)
      end

      MightyTest::Watcher.stub(:new, new_mock_watcher) do
        cli_run(argv: %w[-w --watch])
      end
    end

    private

    def with_fake_minitest_runner
      executed_tests = []
      runner = MinitestRunner.new
      runner.stub(:run_inline_and_exit!, ->(*test_files, **) { executed_tests.append(*test_files.flatten) }) do
        yield(runner, executed_tests)
      end
    end

    def cli_run(argv:, env: {}, chdir: ".", runner: nil, raise_on_failure: true)
      exitstatus = true

      stdout, stderr = capture_io do
        Dir.chdir(chdir) do
          CLI.new(**{ env:, runner: }.compact).run(argv:)
        end
      rescue SystemExit => e
        exitstatus = e.status
      end

      result = CLIResult.new(stdout, stderr, exitstatus)
      raise "CLI exited with status: #{exitstatus}" if raise_on_failure && result.failure?

      result
    end
  end
end
