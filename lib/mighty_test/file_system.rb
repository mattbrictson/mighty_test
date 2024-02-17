module MightyTest
  class FileSystem
    def find_matching_test_file(path)
      return nil unless path && File.exist?(path) && !Dir.exist?(path)
      return path if path.match?(%r{^test/.*_test.rb$})

      test_path = path[%r{^(?:app|lib)/(.+)\.[^\.]+$}, 1].then { "test/#{_1}_test.rb" }
      test_path if test_path && File.exist?(test_path)
    end
  end
end
