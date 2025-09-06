require "open3"

module MightyTest
  class FileSystem
    def listen(&)
      require "listen"
      Listen.to(*%w[app lib test].select { |p| Dir.exist?(p) }, relative: true, &).tap(&:start)
    end

    def find_matching_test_path(path) # rubocop:disable Metrics/CyclomaticComplexity
      return nil unless path && File.exist?(path) && !Dir.exist?(path)
      return path if path.match?(%r{^test/.*_test.rb$})

      test_path = path[%r{^(?:app|lib)/(.+)\.[^.]+$}, 1]&.then { "test/#{_1}_test.rb" }
      test_path if test_path && File.exist?(test_path)
    end

    def find_test_paths(directory="test")
      glob = File.join(directory, "**/*_test.rb")
      Dir[glob]
    end

    def slow_test_path?(path)
      return false if path.nil?

      path.match?(%r{^test/(e2e|feature|features|integration|system)/})
    end

    def find_new_and_changed_paths
      out, _err, status = Open3.capture3(*%w[git status --porcelain=1 -uall -z --no-renames -- test app lib])
      return [] unless status.success?

      out
        .split("\x0")
        .filter_map { |line| line[/^.. (.+)/, 1] }
        .uniq
    rescue SystemCallError
      []
    end
  end
end
