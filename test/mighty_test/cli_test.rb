require "test_helper"

module MightyTest
  class CLITest < Minitest::Test
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

    private

    def cli_run(argv:, env: {}, stdin: nil, raise_on_failure: true)
      exitstatus = true
      orig_stdin = $stdin
      $stdin = StringIO.new(stdin) if stdin

      stdout, stderr = capture_io do
        CLI.new(env:).run(argv:)
      rescue SystemExit => e
        exitstatus = e.status
      end

      result = CLIResult.new(stdout, stderr, exitstatus)
      raise "CLI exited with status: #{exitstatus}" if raise_on_failure && result.failure?

      result
    ensure
      $stdin = orig_stdin
    end
  end
end
