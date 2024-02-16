require "test_helper"

module MightyTest
  class MtTest < Minitest::Test
    def test_mt_can_run_and_print_version
      result = bundle_exec_mt(argv: ["--version"])

      assert_equal(VERSION, result.stdout.chomp)
    end

    private

    def bundle_exec_mt(argv:, env: { "CI" => nil }, chdir: nil, raise_on_failure: true)
      stdout, stderr = capture_subprocess_io do
        system(env, *%w[bundle exec mt] + argv, { chdir: }.compact)
      end

      result = CLIResult.new(stdout, stderr, Process.last_status.exitstatus)
      raise "mt exited with status: #{exitstatus}" if raise_on_failure && result.failure?

      result
    end
  end
end
