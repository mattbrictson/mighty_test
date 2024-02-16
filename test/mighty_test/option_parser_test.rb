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

    def test_dash_v_is_not_considered_an_abbreviation_of_version
      argv = ["-v"]
      _path_args, extra_args, options = OptionParser.new.parse(argv)

      assert_empty(options)
      assert_equal(["-v"], extra_args)
    end

    def test_handles_mix_of_recognized_and_unrecognized_flags_and_args
      argv = %w[path1 --other path2 --help path3 -X -- path4 --great]
      path_args, extra_args, options = OptionParser.new.parse(argv)

      assert_equal(%w[path1 path2 path3 path4 --great], path_args)
      assert_equal(%w[--other -X], extra_args)
      assert_equal({ help: true }, options)
    end
  end
end
