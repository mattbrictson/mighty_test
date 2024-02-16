module MightyTest
  class CLI
    def initialize(env: ENV, option_parser: OptionParser.new, runner: MinitestRunner.new)
      @env = env.to_h
      @option_parser = option_parser
      @runner = runner
    end

    def run(argv: ARGV)
      @path_args, @extra_args, @options = option_parser.parse(argv)

      if options[:help]
        print_help
      elsif options[:version]
        puts VERSION
      elsif path_args.grep(/.:\d+$/).any?
        run_test_by_line_number
      else
        run_tests_by_path
      end
    rescue Exception => e # rubocop:disable Lint/RescueException
      handle_exception(e)
    end

    private

    attr_reader :env, :path_args, :extra_args, :options, :option_parser, :runner

    def print_help
      # Minitest already prints the `-h, --help` option, so omit mighty_test's
      puts option_parser.to_s.sub(/^\s*-h.*?\n/, "")
      puts
      runner.print_help_and_exit!
    end

    def run_test_by_line_number
      path, line = path_args.first.match(/^(.+):(\d+)$/).captures
      test_name = TestParser.new(path).test_name_at_line(line.to_i)

      if test_name
        runner.run_inline_and_exit!(path, args: ["-n", "/^#{Regexp.quote(test_name)}$/"] + extra_args)
      else
        runner.run_inline_and_exit!(args: extra_args)
      end
    end

    def run_tests_by_path
      runner.run_inline_and_exit!(*path_args, args: extra_args)
    end

    def handle_exception(e) # rubocop:disable Naming/MethodParameterName
      case e
      when SignalException
        exit(128 + e.signo)
      when Errno::EPIPE
        # pass
      else
        raise e
      end
    end
  end
end
