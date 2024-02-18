require "concurrent"

module MightyTest
  class Watcher
    WATCHING_FOR_CHANGES = "Watching for changes to source and test files. Press ctrl-c to exit.".freeze

    def initialize(extra_args: [], file_system: FileSystem.new, system_proc: method(:system))
      @dispatcher = Concurrent::MVar.new
      @extra_args = extra_args
      @file_system = file_system
      @system_proc = system_proc
    end

    def run
      start_listener
      puts WATCHING_FOR_CHANGES
      process_dispatched_events
    ensure
      listener&.stop
    end

    # Normally `run` proceeds indefinitely until the user interrupts with ctrl-c.
    # This is a way to stop it gracefully in unit tests.
    def interrupt
      dispatch { :stop }
    end

    private

    attr_reader :extra_args, :file_system, :listener, :system_proc

    def file_system_changed(modified, added, _removed)
      test_paths = [*modified, *added].filter_map do |path|
        file_system.find_matching_test_file(path)
      end
      return if test_paths.empty?

      run_tests(*test_paths.uniq)
    end

    def run_tests(*test_paths)
      begin
        system_proc.call("mt", *extra_args, "--", *test_paths.flatten)
      rescue Interrupt
        # Pressing ctrl-c kills the fs_event background process, so we have to manually restart it.
        restart_listener
      end
      puts WATCHING_FOR_CHANGES
    end

    def start_listener
      listener.stop if listener && !listener.stopped?
      @listener = file_system.listen do |*args|
        listener.pause
        dispatch do
          file_system_changed(*args)
          listener.start if listener.paused?
        end
      end
    end
    alias restart_listener start_listener

    def dispatch(&block)
      @dispatcher.put(block)
      true
    end

    def process_dispatched_events
      loop do
        result = @dispatcher.take.call
        break if result == :stop
      end
    end
  end
end
