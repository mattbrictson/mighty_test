module MightyTest
  class FileSystem
    def listen(&)
      require "listen"
      Listen.to(*%w[app lib test].select { |p| Dir.exist?(p) }, relative: true, &).tap(&:start)
    end

    def find_matching_test_path(path)
      return nil unless path && File.exist?(path) && !Dir.exist?(path)
      return path if path.match?(%r{^test/.*_test.rb$})

      test_path = path[%r{^(?:app|lib)/(.+)\.[^\.]+$}, 1].then { "test/#{_1}_test.rb" }
      test_path if test_path && File.exist?(test_path)
    end

    def find_test_paths(directory="test")
      glob = File.join(directory, "**/*_test.rb")
      Dir[glob]
    end
  end
end
