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
      project_dir = File.expand_path("../fixtures/example_project", __dir__)
      result = bundle_exec_mt(argv: ["test/focused_test.rb"], chdir: project_dir)

      assert_match(/1 runs, 1 assertions, 0 failures, 0 errors/, result.stdout)
    end

    def test_mt_passes_fail_fast_flag_to_minitest
      project_dir = File.expand_path("../fixtures/example_project", __dir__)
      result = bundle_exec_mt(argv: ["--fail-fast", "test/example_test.rb"], chdir: project_dir)

      assert_match(/Run options:.* --fail-fast/, result.stdout)
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
