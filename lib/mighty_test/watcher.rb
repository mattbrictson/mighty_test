require "concurrent"

module MightyTest
  class Watcher
    WATCHING_FOR_CHANGES = 'Watching for changes to source and test files. Press "q" to quit.'.freeze

    def initialize(console: Console.new, extra_args: [], file_system: FileSystem.new, system_proc: method(:system))
      @event = Concurrent::MVar.new
      @console = console
      @extra_args = extra_args
      @file_system = file_system
      @system_proc = system_proc
    end

    def run(iterations: :indefinitely) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      start_file_system_listener
      start_keypress_listener
      puts WATCHING_FOR_CHANGES

      loop_for(iterations) do
        case await_next_event
        in [:file_system_changed, [_, *] => paths]
          console.clear
          puts paths.join("\n")
          puts
          mt(*paths)
        in [:keypress, "\r" | "\n"]
          console.clear
          puts "Running all tests...\n\n"
          mt
        in [:keypress, "d"]
          console.clear
          if (paths = find_matching_tests_for_new_and_changed_paths).any?
            puts paths.join("\n")
            puts
            mt(*paths)
          else
            puts "No affected test files detected since the last git commit."
            puts WATCHING_FOR_CHANGES
          end
        in [:keypress, "q"]
          break
        else
          nil
        end
      end
    ensure
      puts "\nExiting."
      listener&.stop
    end

    private

    attr_reader :console, :extra_args, :file_system, :listener, :system_proc

    def find_matching_tests_for_new_and_changed_paths
      new_changed = file_system.find_new_and_changed_paths
      new_changed.flat_map { |path| file_system.find_matching_test_path(path) }.uniq
    end

    def mt(*test_paths)
      command = ["mt", *extra_args]
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
      listener.stop if listener && !listener.stopped?

      @listener = file_system.listen do |modified, added, _removed|
        # Pause listener so that subsequent changes are queued up while we are running the tests
        listener.pause unless listener.stopped?

        test_paths = [*modified, *added].filter_map do |path|
          file_system.find_matching_test_path(path)
        end

        post_event(:file_system_changed, test_paths.uniq)
      end
    end
    alias restart_file_system_listener start_file_system_listener

    def start_keypress_listener
      Thread.new do
        loop do
          key = console.wait_for_keypress
          post_event(:keypress, key)
        rescue Interrupt
          retry
        end
      rescue StandardError
        # ignore
      end
    end

    def loop_for(iterations, &)
      iterations == :indefinitely ? loop(&) : iterations.times(&)
    end

    def await_next_event
      listener.start if listener.paused?
      @event.take
    end

    def post_event(*event)
      @event.put(event)
    end
  end
end
