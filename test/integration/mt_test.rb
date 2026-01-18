require "test_helper"

module MightyTest
  class MtTest < Minitest::Test
    include FixturesPath

    def test_mt_can_run_and_print_version
      result = bundle_exec_mt(argv: ["--version"])

      assert_equal(VERSION, result.stdout.chomp)
    end

    def test_mt_runs_a_successful_test
      project_dir = fixtures_path.join("example_project")
      result = bundle_exec_mt(argv: ["test/example_test.rb"], chdir: project_dir)

      assert_match(/Run options:.* --seed \d+/, result.stdout)
      assert_match(/Finished/, result.stdout)
      assert_match(/\d runs, \d assertions, 0 failures, 0 errors/, result.stdout)
    end

    def test_mt_runs_a_failing_test_and_exits_with_non_zero_status
      project_dir = fixtures_path.join("example_project")
      result = bundle_exec_mt(argv: ["test/failing_test.rb"], chdir: project_dir, raise_on_failure: false)

      assert_predicate(result, :failure?)
      assert_match(/\d runs, \d assertions, 1 failures, 0 errors/, result.stdout)
    end

    def test_mt_supports_test_focus
      project_dir = fixtures_path.join("example_project")
      result = bundle_exec_mt(argv: ["test/focused_test.rb"], chdir: project_dir)

      assert_match(/\b1 runs, 1 assertions, 0 failures, 0 errors/, result.stdout)
    end

    def test_mt_passes_fail_fast_flag_to_minitest
      project_dir = fixtures_path.join("example_project")
      result = bundle_exec_mt(argv: ["--fail-fast", "test/example_test.rb"], chdir: project_dir)

      assert_match(/Run options:.* --fail-fast/, result.stdout)
    end

    def test_mt_runs_a_single_test_by_line_number_with_verbose_output
      project_dir = fixtures_path.join("example_project")
      result = bundle_exec_mt(argv: ["--verbose", "test/failing_test.rb:9"], chdir: project_dir)

      assert_includes(result.stdout, "FailingTest#test_assertion_succeeds")
      assert_match(/\b1 assertions/, result.stdout)
    end

    def test_mt_runs_no_tests_if_line_number_doesnt_match
      project_dir = fixtures_path.join("example_project")
      result = bundle_exec_mt(argv: ["--verbose", "test/failing_test.rb:2"], chdir: project_dir)

      assert_match(/Run options:.* --verbose/, result.stdout)
      refute_match(/FailingTest/, result.stdout)
    end

    def test_mt_runs_watch_mode_that_executes_tests_when_files_change # rubocop:disable Minitest/MultipleAssertions
      project_dir = fixtures_path.join("example_project")
      stdout, stderr = capture_subprocess_io do
        # Start mt --watch in the background
        pid = spawn(*%w[bundle exec mt --watch --verbose], chdir: project_dir)

        # mt needs time to launch and start its file system listener
        sleep 1

        # Touch a file and wait for mt --watch to detect the change and run the corresponding test
        FileUtils.touch project_dir.join("lib/example.rb")
        sleep 1

        # OK, we're done here. Tell mt --watch to exit.
        Process.kill(:TERM, pid)
      end

      assert_empty(stderr)

      assert_includes(stdout, "Watching for changes to source and test files.")
      assert_match(/ExampleTest/, stdout)
      assert_match(/\d runs, \d assertions, 0 failures, 0 errors/, stdout)
    end

    private

    def bundle_exec_mt(argv:, env: { "CI" => nil }, chdir: nil, raise_on_failure: true)
      stdout, stderr = capture_subprocess_io do
        system(env, *%w[bundle exec mt] + argv, { chdir: }.compact)
      end

      exitstatus = Process.last_status.exitstatus
      result = CLIResult.new(stdout, stderr, exitstatus)
      raise "mt exited with status: #{exitstatus} and output: #{stdout + stderr}" if raise_on_failure && result.failure?

      result
    end
  end
end
