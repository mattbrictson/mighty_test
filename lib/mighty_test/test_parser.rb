module MightyTest
  class TestParser
    def initialize(test_path)
      @path = test_path.to_s
    end

    def test_name_at_line(number)
      method_name = nil
      lines = File.read(path).lines
      lines[2...number].reverse_each.find do |line|
        method_name =
          match_minitest_method_name(line) ||
          match_active_support_test_string(line)&.then { "test_#{_1.gsub(/\s+/, '_')}" }
      end
      method_name
    end

    private

    attr_reader :path

    def match_minitest_method_name(line)
      line[/^\s+(?:focus\s+)?def (test_\w+)/, 1]
    end

    def match_active_support_test_string(line)
      match = line.match(/^\s*test\s+(?:"(.+?)"|'(.+?)')\s*do\s*(?:#.*?)?$/)
      return unless match

      match.captures.compact.first
    end
  end
end
