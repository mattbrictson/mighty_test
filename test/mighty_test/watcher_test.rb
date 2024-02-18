require "test_helper"

module MightyTest
  class WatcherTest < Minitest::Test
    include FixturesPath

    def test_watcher_passes_unique_set_of_test_files_to_mt_command_based_on_changes_detected
      system_proc { |*args| puts "[SYSTEM] #{args.join(' ')}" }
      listen_thread do |callback|
        callback.call(["lib/example.rb", "test/focused_test.rb"], ["test/focused_test.rb"], [])
        @watcher.interrupt
      end

      stdout, = run_watcher(in: fixtures_path.join("example_project"))

      assert_includes(stdout, "[SYSTEM] mt -- test/example_test.rb test/focused_test.rb\n")
    end

    def test_watcher_passes_extra_args_through_to_mt_command
      system_proc { |*args| puts "[SYSTEM] #{args.join(' ')}" }
      listen_thread do |callback|
        callback.call(["test/example_test.rb"], [], [])
        @watcher.interrupt
      end

      stdout, = run_watcher(extra_args: ["--fail-fast"], in: fixtures_path.join("example_project"))

      assert_includes(stdout, "[SYSTEM] mt --fail-fast -- test/example_test.rb\n")
    end

    def test_watcher_prints_a_status_message_after_successful_test_run
      system_proc do |*args|
        puts "[SYSTEM] #{args.join(' ')}"
        true
      end
      listen_thread do |callback|
        callback.call(["test/example_test.rb"], [], [])
        @watcher.interrupt
      end

      stdout, = run_watcher(in: fixtures_path.join("example_project"))

      assert_includes(stdout, <<~EXPECTED)
        [SYSTEM] mt -- test/example_test.rb
        Watching for changes to source and test files. Press ctrl-c to exit.
      EXPECTED
    end

    def test_watcher_prints_a_status_message_after_failed_test_run
      system_proc do |*args|
        puts "[SYSTEM] #{args.join(' ')}"
        false
      end
      listen_thread do |callback|
        callback.call(["test/example_test.rb"], [], [])
        @watcher.interrupt
      end

      stdout, = run_watcher(in: fixtures_path.join("example_project"))

      assert_includes(stdout, <<~EXPECTED)
        [SYSTEM] mt -- test/example_test.rb
        Watching for changes to source and test files. Press ctrl-c to exit.
      EXPECTED
    end

    def test_watcher_does_nothing_if_a_detected_change_has_no_corresponding_test_file
      system_proc { |*args| puts "[SYSTEM] #{args.join(' ')}" }
      listen_thread do |callback|
        callback.call(["lib/example/version.rb"], [], [])
        @watcher.interrupt
      end

      stdout, = run_watcher(in: fixtures_path.join("example_project"))

      refute_includes(stdout, "[SYSTEM]")
    end

    def test_watcher_restarts_the_listener_when_a_test_run_is_interrupted
      thread_count = 0
      system_proc { |*| raise Interrupt }
      listen_thread do |callback|
        thread_count += 1
        callback.call(["test/example_test.rb"], [], [])
        @watcher.interrupt if thread_count > 1
      end

      run_watcher(in: fixtures_path.join("example_project"))

      assert_equal(2, thread_count)
    end

    private

    class ListenThread
      def initialize(thread, callback)
        Thread.new do
          thread.call(callback)
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

    def run_watcher(in: ".", extra_args: [])
      listen_thread = @listen_thread
      file_system = FileSystem.new
      file_system.define_singleton_method(:listen) { |&callback| ListenThread.new(listen_thread, callback) }
      capture_io do
        Dir.chdir(binding.local_variable_get(:in)) do
          @watcher = Watcher.new(extra_args:, file_system:, system_proc: @system_proc)
          @watcher.run
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
