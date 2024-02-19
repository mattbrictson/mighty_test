require "concurrent"

module MightyTest
  class Watcher
    WATCHING_FOR_CHANGES = "Watching for changes to source and test files. Press ctrl-c to exit.".freeze

    def initialize(extra_args: [], file_system: FileSystem.new, system_proc: method(:system))
      @event = Concurrent::MVar.new
      @extra_args = extra_args
      @file_system = file_system
      @system_proc = system_proc
    end

    def run(iterations: :indefinitely)
      start_listener
      puts WATCHING_FOR_CHANGES

      loop_for(iterations) do
        case await_next_event
        in [:file_system_changed, paths]
          mt(*paths) if paths.any?
        in [:tests_completed, :pass | :fail]
          puts WATCHING_FOR_CHANGES
        end
      end
    ensure
      listener&.stop
    end

    private

    attr_reader :extra_args, :file_system, :listener, :system_proc

    def mt(*test_paths)
      success = system_proc.call("mt", *extra_args, "--", *test_paths.flatten)
      post_event(:tests_completed, success ? :pass : :fail)
    rescue Interrupt
      # Pressing ctrl-c kills the fs_event background process, so we have to manually restart it.
      restart_listener
    end

    def start_listener
      listener.stop if listener && !listener.stopped?

      @listener = file_system.listen do |modified, added, _removed|
        # Pause listener so that subsequent changes are queued up while we are running the tests
        listener.pause unless listener.stopped?

        test_paths = [*modified, *added].filter_map do |path|
          file_system.find_matching_test_file(path)
        end

        post_event(:file_system_changed, test_paths.uniq)
      end
    end
    alias restart_listener start_listener

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
