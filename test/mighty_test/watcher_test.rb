require "test_helper"

module MightyTest
  class WatcherTest < Minitest::Test
    include FixturesPath

    def setup
      @event_queue = FakeEventQueue.new
      @system_proc = nil
    end

    def test_watcher_passes_unique_set_of_test_files_to_mt_command_based_on_changes_detected
      system_proc { |*args| puts "[SYSTEM] #{args.join(' ')}" }
      event_queue.push :file_system_changed, %w[lib/example.rb test/focused_test.rb test/focused_test.rb]
      event_queue.push :keypress, "q"

      stdout, = run_watcher(in: fixtures_path.join("example_project"))

      assert_includes(stdout, "[SYSTEM] mt -- test/example_test.rb test/focused_test.rb\n")
    end

    def test_watcher_does_nothing_if_a_detected_change_has_no_corresponding_test_file
      system_proc { |*args| puts "[SYSTEM] #{args.join(' ')}" }
      event_queue.push :file_system_changed, %w[lib/example/version.rb]
      event_queue.push :keypress, "q"

      stdout, = run_watcher(in: fixtures_path.join("example_project"))

      refute_includes(stdout, "[SYSTEM]")
    end

    def test_watcher_passes_extra_args_through_to_mt_command
      system_proc { |*args| puts "[SYSTEM] #{args.join(' ')}" }
      event_queue.push :file_system_changed, %w[test/example_test.rb]
      event_queue.push :keypress, "q"

      stdout, = run_watcher(extra_args: %w[-w --fail-fast], in: fixtures_path.join("example_project"))

      assert_includes(stdout, "[SYSTEM] mt -w --fail-fast -- test/example_test.rb\n")
    end

    def test_watcher_clears_the_screen_and_prints_the_test_file_being_run_prior_to_executing_the_mt_command
      system_proc { |*args| puts "[SYSTEM] #{args.join(' ')}" }
      event_queue.push :file_system_changed, %w[test/example_test.rb]
      event_queue.push :keypress, "q"

      stdout, = run_watcher(in: fixtures_path.join("example_project"))

      assert_includes(stdout, <<~EXPECTED)
        [CLEAR]
        test/example_test.rb

        [SYSTEM] mt -- test/example_test.rb
      EXPECTED
    end

    def test_watcher_prints_a_status_message_and_plays_a_sound_after_successful_test_run
      system_proc do |*args|
        puts "[SYSTEM] #{args.join(' ')}"
        true
      end
      event_queue.push :file_system_changed, %w[test/example_test.rb]
      event_queue.push :keypress, "q"

      stdout, = run_watcher(in: fixtures_path.join("example_project"))

      assert_includes(stdout, <<~EXPECTED)
        [SYSTEM] mt -- test/example_test.rb
        [SOUND] :pass

        Watching for changes to source and test files. Press "h" for help or "q" to quit.
      EXPECTED
    end

    def test_watcher_prints_a_status_message_and_plays_a_sound_after_failed_test_run
      system_proc do |*args|
        puts "[SYSTEM] #{args.join(' ')}"
        false
      end
      event_queue.push :file_system_changed, %w[test/example_test.rb]
      event_queue.push :keypress, "q"

      stdout, = run_watcher(in: fixtures_path.join("example_project"))

      assert_includes(stdout, <<~EXPECTED)
        [SYSTEM] mt -- test/example_test.rb
        [SOUND] :fail

        Watching for changes to source and test files. Press "h" for help or "q" to quit.
      EXPECTED
    end

    def test_watcher_restarts_the_listener_when_a_test_run_is_interrupted
      restarted = false
      system_proc { |*| raise Interrupt }

      event_queue.push :file_system_changed, %w[test/example_test.rb]
      event_queue.push :keypress, "q"
      event_queue.define_singleton_method(:restart) { restarted = true }

      run_watcher(in: fixtures_path.join("example_project"))
      assert restarted
    end

    def test_watcher_exits_when_q_key_is_pressed
      event_queue.push :keypress, "q"
      stdout, = run_watcher(in: fixtures_path.join("example_project"))

      assert_includes(stdout, "Exiting.")
    end

    def test_watcher_runs_all_tests_when_enter_key_is_pressed
      system_proc do |*args|
        puts "[SYSTEM] #{args.join(' ')}"
        true
      end
      event_queue.push :keypress, "\r"
      event_queue.push :keypress, "q"

      stdout, = run_watcher(in: fixtures_path.join("example_project"))

      assert_includes(stdout, <<~EXPECTED)
        Running tests...

        [SYSTEM] mt
      EXPECTED
    end

    def test_watcher_runs_all_tests_with_all_flag_when_a_key_is_pressed
      system_proc do |*args|
        puts "[SYSTEM] #{args.join(' ')}"
        true
      end
      event_queue.push :keypress, "a"
      event_queue.push :keypress, "q"

      stdout, = run_watcher(in: fixtures_path.join("example_project"))

      assert_includes(stdout, <<~EXPECTED)
        Running tests with --all...

        [SYSTEM] mt --all
      EXPECTED
    end

    def test_watcher_runs_new_and_changed_files_according_to_git_when_d_key_is_pressed
      system_proc do |*args|
        puts "[SYSTEM] #{args.join(' ')}"
        true
      end
      event_queue.push :keypress, "d"
      event_queue.push :keypress, "q"

      file_system = FileSystem.new
      stdout, = file_system.stub(:find_new_and_changed_paths, %w[lib/example.rb]) do
        run_watcher(file_system:, in: fixtures_path.join("example_project"))
      end

      assert_includes(stdout, <<~EXPECTED)
        [CLEAR]
        test/example_test.rb

        [SYSTEM] mt -- test/example_test.rb
      EXPECTED
    end

    def test_watcher_shows_a_message_if_d_key_is_pressed_and_there_are_no_changes
      system_proc do |*args|
        puts "[SYSTEM] #{args.join(' ')}"
        true
      end
      event_queue.push :keypress, "d"
      event_queue.push :keypress, "q"

      file_system = FileSystem.new
      stdout, = file_system.stub(:find_new_and_changed_paths, []) do
        run_watcher(file_system:, in: fixtures_path.join("example_project"))
      end

      assert_includes(stdout, <<~EXPECTED)
        [CLEAR]
        No affected test files detected since the last git commit.
        Watching for changes to source and test files. Press "h" for help or "q" to quit.
      EXPECTED
    end

    def test_watcher_shows_help_menu_when_h_key_is_pressed
      event_queue.push :keypress, "h"
      event_queue.push :keypress, "q"

      stdout, = run_watcher(in: fixtures_path.join("example_project"))

      assert_includes(stdout, <<~EXPECTED)
        > Press Enter to run all tests.
        > Press "a" to run all tests, including slow tests.
        > Press "d" to run tests for files diffed or added since the last git commit.
        > Press "h" to show this help menu.
        > Press "q" to quit.
      EXPECTED
    end

    private

    attr_reader :event_queue

    class FakeEventQueue
      def initialize
        @events = []
      end

      def push(type, payload)
        @events.unshift([type, payload])
      end

      def pop
        @events.pop
      end

      def start; end
      def stop; end
    end

    def run_watcher(in: ".", file_system: FileSystem.new, extra_args: [])
      console = Console.new
      console.define_singleton_method(:clear) { puts "[CLEAR]" }
      console.define_singleton_method(:play_sound) { |sound| puts "[SOUND] #{sound.inspect}" }

      capture_io do
        Dir.chdir(binding.local_variable_get(:in)) do
          @watcher = Watcher.new(console:, extra_args:, event_queue:, file_system:, system_proc: @system_proc)
          @watcher.run
        end
      end
    end

    def system_proc(&proc)
      @system_proc = proc
    end
  end
end
