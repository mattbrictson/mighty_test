module MightyTest
  class Watcher
    class ListenerTriggered < StandardError
      attr_reader :paths

      def initialize(paths)
        @paths = paths
        super()
      end
    end

    WATCHING_FOR_CHANGES = 'Watching for changes to source and test files. Press "h" for help or "q" to quit.'.freeze

    def initialize(console: Console.new, extra_args: [], file_system: FileSystem.new, system_proc: method(:system))
      @console = console
      @extra_args = extra_args
      @file_system = file_system
      @system_proc = system_proc
    end

    def run(iterations: :indefinitely) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
      started = false
      @foreground_thread = Thread.current

      loop_for(iterations) do
        start_file_system_listener && puts(WATCHING_FOR_CHANGES) unless started
        started = true

        case console.wait_for_keypress
        when "\r", "\n"
          run_all_tests
        when "a"
          run_all_tests(flags: ["--all"])
        when "d"
          run_matching_test_files_from_git_diff
        when "h"
          show_help
        when "q"
          file_system_listener.stop
          break
        end
      rescue ListenerTriggered => e
        run_matching_test_files(e.paths)
        file_system_listener.start if file_system_listener.paused?
      rescue Interrupt
        file_system_listener&.stop
        raise
      end
    ensure
      puts "\nExiting."
    end

    private

    attr_reader :console, :extra_args, :file_system, :file_system_listener, :system_proc, :foreground_thread

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
      # Do this in a separate thread to work around odd behavior on Ruby 3.4.
      Thread.new { restart_file_system_listener }
    end

    def start_file_system_listener
      file_system_listener.stop if file_system_listener && !file_system_listener.stopped?

      @file_system_listener = file_system.listen do |modified, added, _removed|
        paths = [*modified, *added].uniq
        next if paths.empty?

        # Pause listener so that subsequent changes are queued up while we are running the tests
        file_system_listener.pause unless file_system_listener.stopped?
        foreground_thread.raise ListenerTriggered.new(paths)
      end
    end
    alias restart_file_system_listener start_file_system_listener

    def loop_for(iterations, &)
      iterations == :indefinitely ? loop(&) : iterations.times(&)
    end
  end
end
