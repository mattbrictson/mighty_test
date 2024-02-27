module MightyTest
  class Watcher # rubocop:disable Metrics/ClassLength
    WATCHING_FOR_CHANGES = 'Watching for changes to source and test files. Press "h" for help or "q" to quit.'.freeze

    def initialize(console: Console.new, extra_args: [], file_system: FileSystem.new, system_proc: method(:system))
      @queue = Thread::Queue.new
      @console = console
      @extra_args = extra_args
      @file_system = file_system
      @system_proc = system_proc
    end

    def run(iterations: :indefinitely) # rubocop:disable Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
      start_file_system_listener
      start_keypress_listener
      puts WATCHING_FOR_CHANGES

      loop_for(iterations) do
        case await_next_event
        in [:file_system_changed, [_, *] => paths]
          run_matching_test_files(paths)
        in [:keypress, "\r" | "\n"]
          run_all_tests
        in [:keypress, "a"]
          run_all_tests(flags: ["--all"])
        in [:keypress, "d"]
          run_matching_test_files_from_git_diff
        in [:keypress, "h"]
          show_help
        in [:keypress, "q"]
          break
        else
          nil
        end
      end
    ensure
      puts "\nExiting."
      file_system_listener&.stop
      keypress_listener&.kill
    end

    private

    attr_reader :console, :extra_args, :file_system, :file_system_listener, :keypress_listener, :system_proc

    def show_help
      console.clear
      puts <<~MENU
        `mt --watch` is watching file system activity and will automatically run
        test files when they are added or modified. If you modify a source file,
        mt will find and run the corresponding tests.

        You can also trigger test runs with the following interactive commands.

        > Press Enter to run all tests.
        > Press "a" to run all tests, including slow tests.
        > Press "d" to run tests for files diffed or added since the last git commit.
        > Press "h" to show this help menu.
        > Press "q" to quit.

      MENU
    end

    def run_all_tests(flags: [])
      console.clear
      puts flags.any? ? "Running tests with #{flags.join(' ')}..." : "Running tests..."
      puts
      mt(flags:)
    end

    def run_matching_test_files(paths)
      test_paths = paths.flat_map { |path| file_system.find_matching_test_path(path) }.compact.uniq
      return false if test_paths.empty?

      console.clear
      puts test_paths.join("\n")
      puts
      mt(*test_paths)
      true
    end

    def run_matching_test_files_from_git_diff
      return if run_matching_test_files(file_system.find_new_and_changed_paths)

      console.clear
      puts "No affected test files detected since the last git commit."
      puts WATCHING_FOR_CHANGES
    end

    def mt(*test_paths, flags: [])
      command = ["mt", *extra_args, *flags]
      command.append("--", *test_paths.flatten) if test_paths.any?

      success = system_proc.call(*command)

      console.play_sound(success ? :pass : :fail)
      puts "\n#{WATCHING_FOR_CHANGES}"
      $stdout.flush
    rescue Interrupt
      # Pressing ctrl-c kills the fs_event background process, so we have to manually restart it.
      restart_file_system_listener
    end

    def start_file_system_listener
      file_system_listener.stop if file_system_listener && !file_system_listener.stopped?

      @file_system_listener = file_system.listen do |modified, added, _removed|
        # Pause listener so that subsequent changes are queued up while we are running the tests
        file_system_listener.pause unless file_system_listener.stopped?
        post_event(:file_system_changed, [*modified, *added].uniq)
      end
    end
    alias restart_file_system_listener start_file_system_listener

    def start_keypress_listener
      @keypress_listener = Thread.new do
        loop do
          key = console.wait_for_keypress
          break if key.nil?

          post_event(:keypress, key)
        end
      end
      @keypress_listener.abort_on_exception = true
    end

    def loop_for(iterations, &)
      iterations == :indefinitely ? loop(&) : iterations.times(&)
    end

    def await_next_event
      file_system_listener.start if file_system_listener.paused?
      @queue.pop
    end

    def post_event(*event)
      @queue << event
    end
  end
end
