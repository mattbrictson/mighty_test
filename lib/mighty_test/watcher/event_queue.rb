require "io/console"

module MightyTest
  class Watcher
    class EventQueue
      def initialize(console: Console.new, file_system: FileSystem.new)
        @console = console
        @file_system = file_system
        @file_system_queue = Thread::Queue.new
      end

      def pop
        console.with_raw_input do
          until stopped?
            if (key = console.read_keypress_nonblock)
              return [:keypress, key]
            end
            if (paths = pop_files_changed)
              return [:file_system_changed, paths]
            end
          end
        end
      end

      def start
        raise "Already started" unless stopped?

        @file_system_listener = file_system.listen do |modified, added, _removed|
          paths = [*modified, *added].uniq
          file_system_queue.push(paths) unless paths.empty?
        end
        true
      end

      def restart
        stop
        start
      end

      def stop
        file_system_listener&.stop
        @file_system_listener = nil
      end

      def stopped?
        !file_system_listener
      end

      private

      attr_reader :console, :file_system, :file_system_listener, :file_system_queue

      def pop_files_changed
        paths = try_file_system_pop(timeout: 0.2)
        return if paths.nil?

        paths += file_system_queue.pop until file_system_queue.empty?
        paths.uniq
      end

      if RUBY_VERSION.start_with?("3.1.")
        # TODO: Remove once we drop support for Ruby 3.1
        require "timeout"
        def try_file_system_pop(timeout:)
          Timeout.timeout(timeout) do
            file_system_queue.pop
          end
        rescue Timeout::Error
          nil
        end
      else
        def try_file_system_pop(timeout:)
          file_system_queue.pop(timeout:)
        end
      end
    end
  end
end
