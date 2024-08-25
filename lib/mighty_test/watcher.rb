require_relative "watcher/event_queue"

module MightyTest
  class Watcher
    WATCHING_FOR_CHANGES = 'Watching for changes to source and test files. Press "h" for help or "q" to quit.'.freeze

    def initialize(console: Console.new, extra_args: [], event_queue: nil, file_system: nil, system_proc: nil)
      @console = console
      @extra_args = extra_args
      @file_system = file_system || FileSystem.new
      @system_proc = system_proc || method(:system)
      @event_queue = event_queue || EventQueue.new(console: @console, file_system: @file_system)
    end

    def run
      event_queue.start
      puts WATCHING_FOR_CHANGES

      loop do
        case event_queue.pop
        in [:file_system_changed, [_, *] => paths] then run_matching_test_files(paths)
        in [:keypress, "\r" | "\n"] then run_all_tests
        in [:keypress, "a"] then run_all_tests(flags: ["--all"])
        in [:keypress, "d"] then run_matching_test_files_from_git_diff
        in [:keypress, "h"] then show_help
        in [:keypress, "q"] then break
        else
          nil
        end
      end
    ensure
      event_queue.stop
      puts "\nExiting."
    end

    private

    attr_reader :console, :extra_args, :file_system, :event_queue, :system_proc

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
      event_queue.restart
    end
  end
end
