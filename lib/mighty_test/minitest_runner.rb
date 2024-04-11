module MightyTest
  class MinitestRunner
    def print_help_and_exit!
      require "minitest"
      Minitest.run(["--help"])
      exit
    end

    def run_inline_and_exit!(*test_files, args: [], warnings: false)
      $VERBOSE = warnings
      $LOAD_PATH.unshift "test"
      ARGV.replace(Array(args))

      require "minitest"
      require "minitest/focus"
      require "minitest/rg"

      test_files.flatten.each { |file| require File.expand_path(file.to_s) }

      require "minitest/autorun"
      exit
    end
  end
end
