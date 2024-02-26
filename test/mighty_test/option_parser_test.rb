require "test_helper"

module MightyTest
  class OptionParserTest < Minitest::Test
    def test_parses_known_flags_into_options
      argv = %w[-h --version]
      _path_args, _extra_args, options = OptionParser.new.parse(argv)

      assert_equal(
        {
          help: true,
          version: true
        },
        options
      )
    end

    def test_doesnt_return_seed_args_if_they_werent_specified
      argv = %w[-f]
      _path_args, extra_args, _options = OptionParser.new.parse(argv)

      assert_equal %w[-f], extra_args
    end

    def test_dash_v_is_not_considered_an_abbreviation_of_version
      argv = ["-v"]
      _path_args, extra_args, options = OptionParser.new.parse(argv)

      assert_empty(options)
      assert_includes(extra_args, "-v")
    end

    def test_shard_value_can_be_specified_with_equals_sign
      argv = %w[--shard=1/2]
      path_args, extra_args, options = OptionParser.new.parse(argv)

      assert_empty(path_args)
      assert_empty(extra_args)
      assert_equal("1/2", options[:shard])
    end

    def test_shard_value_can_be_specified_without_equals_sign
      argv = %w[--shard 1/2]
      path_args, extra_args, options = OptionParser.new.parse(argv)

      assert_empty(path_args)
      assert_empty(extra_args)
      assert_equal("1/2", options[:shard])
    end

    def test_places_minitest_seed_option_into_extra_args
      argv = %w[--seed 1234]
      path_args, extra_args, = OptionParser.new.parse(argv)

      assert_empty(path_args)
      assert_equal(%w[--seed 1234], extra_args)
    end

    def test_handles_mix_of_mt_and_minitest_flags_and_args
      argv = %w[path1 --seed 1234 path2 --shard 1/2 path3 -f --all -- path4 --great]
      path_args, extra_args, options = OptionParser.new.parse(argv)

      assert_equal(%w[path1 path2 path3 path4 --great], path_args)
      assert_equal(%w[--seed 1234 -f], extra_args)
      assert_equal({ all: true, shard: "1/2" }, options)
    end

    def test_exits_with_failing_status_on_unrecognized_flag
      argv = %w[--non-existent]
      exitstatus = nil

      stdout, = capture_io do
        OptionParser.new.parse(argv)
      rescue SystemExit => e
        exitstatus = e.status
      end

      assert_equal 1, exitstatus
      assert_includes(stdout, "invalid option: --non-existent")
    end
  end
end
