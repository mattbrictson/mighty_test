require "test_helper"

module MightyTest
  class WatcherTest < Minitest::Test
    include FixturesPath

    def test_watcher_passes_unique_set_of_test_files_to_mt_command_based_on_changes_detected
      system_proc { |*args| puts "[SYSTEM] #{args.join(' ')}" }
      listen_thread do |callback|
        callback.call(["lib/example.rb", "test/focused_test.rb"], ["test/focused_test.rb"], [])
      end

      stdout, = run_watcher(iterations: 1, in: fixtures_path.join("example_project"))

      assert_includes(stdout, "[SYSTEM] mt -- test/example_test.rb test/focused_test.rb\n")
    end

    def test_watcher_does_nothing_if_a_detected_change_has_no_corresponding_test_file
      system_proc { |*args| puts "[SYSTEM] #{args.join(' ')}" }
      listen_thread do |callback|
        callback.call(["lib/example/version.rb"], [], [])
      end

      stdout, = run_watcher(iterations: 1, in: fixtures_path.join("example_project"))

      refute_includes(stdout, "[SYSTEM]")
    end

    def test_watcher_passes_extra_args_through_to_mt_command
      system_proc { |*args| puts "[SYSTEM] #{args.join(' ')}" }
      listen_thread do |callback|
        callback.call(["test/example_test.rb"], [], [])
      end

      stdout, = run_watcher(iterations: 1, extra_args: ["--fail-fast"], in: fixtures_path.join("example_project"))

      assert_includes(stdout, "[SYSTEM] mt --fail-fast -- test/example_test.rb\n")
    end

    def test_watcher_clears_the_screen_and_prints_the_test_file_being_run_prior_to_executing_the_mt_command
      system_proc { |*args| puts "[SYSTEM] #{args.join(' ')}" }
      listen_thread do |callback|
        callback.call(["test/example_test.rb"], [], [])
      end

      stdout, = run_watcher(iterations: 1, in: fixtures_path.join("example_project"))

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
      listen_thread do |callback|
        callback.call(["test/example_test.rb"], [], [])
      end

      stdout, = run_watcher(iterations: 1, in: fixtures_path.join("example_project"))

      assert_includes(stdout, <<~EXPECTED)
        [SYSTEM] mt -- test/example_test.rb
        [SOUND] :pass

        Watching for changes to source and test files. Press "q" to quit.
      EXPECTED
    end

    def test_watcher_prints_a_status_message_and_plays_a_sound_after_failed_test_run
      system_proc do |*args|
        puts "[SYSTEM] #{args.join(' ')}"
        false
      end
      listen_thread do |callback|
        callback.call(["test/example_test.rb"], [], [])
      end

      stdout, = run_watcher(iterations: 1, in: fixtures_path.join("example_project"))

      assert_includes(stdout, <<~EXPECTED)
        [SYSTEM] mt -- test/example_test.rb
        [SOUND] :fail

        Watching for changes to source and test files. Press "q" to quit.
      EXPECTED
    end

    def test_watcher_restarts_the_listener_when_a_test_run_is_interrupted
      thread_count = 0
      system_proc { |*| raise Interrupt }
      listen_thread do |callback|
        thread_count += 1
        callback.call(["test/example_test.rb"], [], []) unless thread_count > 2
      end

      run_watcher(iterations: 2, in: fixtures_path.join("example_project"))
      assert_equal(2, thread_count)
    end

    def test_watcher_exits_when_q_key_is_pressed
      stdout, = run_watcher(stdin: "q", in: fixtures_path.join("example_project"))

      assert_includes(stdout, "Exiting.")
    end

    def test_watcher_runs_all_tests_when_enter_key_is_pressed
      system_proc do |*args|
        puts "[SYSTEM] #{args.join(' ')}"
        true
      end

      stdout, = run_watcher(stdin: "\rq", in: fixtures_path.join("example_project"))

      assert_includes(stdout, <<~EXPECTED)
        Running all tests...

        [SYSTEM] mt
      EXPECTED
    end

    def test_watcher_runs_new_and_changed_files_according_to_git_when_d_key_is_pressed
      system_proc do |*args|
        puts "[SYSTEM] #{args.join(' ')}"
        true
      end

      file_system = FileSystem.new
      stdout, = file_system.stub(:find_new_and_changed_paths, %w[lib/example.rb]) do
        run_watcher(file_system:, stdin: "dq", in: fixtures_path.join("example_project"))
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

      file_system = FileSystem.new
      stdout, = file_system.stub(:find_new_and_changed_paths, []) do
        run_watcher(file_system:, stdin: "dq", in: fixtures_path.join("example_project"))
      end

      assert_includes(stdout, <<~EXPECTED)
        [CLEAR]
        No affected test files detected since the last git commit.
        Watching for changes to source and test files. Press "q" to quit.
      EXPECTED
    end

    private

    class Listener
      def initialize(thread, callback)
        Thread.new do
          thread&.call(callback)
        end
      end

      def start
      end

      def stop
      end

      def pause
      end

      def stopped?
        false
      end

      def paused?
        false
      end
    end

    def run_watcher(iterations: :indefinitely, in: ".", extra_args: [], stdin: nil, file_system: FileSystem.new)
      listen_thread = @listen_thread
      console = Console.new(stdin: stdin.nil? ? File::NULL : StringIO.new(stdin))
      console.define_singleton_method(:clear) { puts "[CLEAR]" }
      console.define_singleton_method(:play_sound) { |sound| puts "[SOUND] #{sound.inspect}" }
      file_system.define_singleton_method(:listen) { |&callback| Listener.new(listen_thread, callback) }

      capture_io do
        Dir.chdir(binding.local_variable_get(:in)) do
          @watcher = Watcher.new(console:, extra_args:, file_system:, system_proc: @system_proc)
          @watcher.run(iterations:)
        end
      end
    end

    def listen_thread(&thread)
      @listen_thread = thread
    end

    def system_proc(&proc)
      @system_proc = proc
    end
  end
end
