module MightyTest
  class MinitestRunner
    def print_help_and_exit!
      require "minitest"
      Minitest.run(["--help"])
      exit
    end
  end
end
