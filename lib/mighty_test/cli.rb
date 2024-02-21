module MightyTest
  class CLI
    def initialize(file_system: FileSystem.new, env: ENV, option_parser: OptionParser.new, runner: MinitestRunner.new)
      @file_system = file_system
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
      elsif options[:watch]
        watch
      elsif path_args.grep(/.:\d+$/).any?
        run_test_by_line_number
      else
        run_tests_by_path
      end
    rescue Exception => e # rubocop:disable Lint/RescueException
      handle_exception(e)
    end

    private

    attr_reader :file_system, :env, :path_args, :extra_args, :options, :option_parser, :runner

    def print_help
      # Minitest already prints the `-h, --help` option, so omit mighty_test's
      puts option_parser.to_s.sub(/^\s*-h.*?\n/, "")
      puts
      runner.print_help_and_exit!
    end

    def watch
      Watcher.new(extra_args:).run
    end

    def run_test_by_line_number
      path, line = path_args.first.match(/^(.+):(\d+)$/).captures
      test_name = TestParser.new(path).test_name_at_line(line.to_i)

      if test_name
        run_tests_and_exit!(path, flags: ["-n", "/^#{Regexp.quote(test_name)}$/"])
      else
        run_tests_and_exit!
      end
    end

    def run_tests_by_path
      test_paths = find_test_paths
      run_tests_and_exit!(*test_paths)
    end

    def find_test_paths
      return file_system.find_test_paths if path_args.empty?

      path_args.flat_map do |path|
        if Dir.exist?(path)
          file_system.find_test_paths(path)
        elsif File.exist?(path)
          [path]
        else
          raise ArgumentError, "#{path} does not exist"
        end
      end
    end

    def run_tests_and_exit!(*test_paths, flags: [])
      runner.run_inline_and_exit!(*test_paths, args: extra_args + flags)
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
