require "shellwords"

module MightyTest
  class OptionParser
    def parse(argv)
      argv, literal_args = split(argv, "--")
      options = parse_options!(argv)
      minitest_flags = parse_minitest_flags!(argv) unless options[:help]

      [argv + literal_args, minitest_flags || [], options]
    end

    def to_s
      <<~USAGE
        Usage: mt [--all]
               mt [test file...] [test dir...]
               mt --watch
      USAGE
    end

    private

    def parse_options!(argv)
      options = {}
      options[:all] = true if argv.delete("--all")
      options[:watch] = true if argv.delete("--watch")
      options[:version] = true if argv.delete("--version")
      options[:help] = true if argv.delete("--help") || argv.delete("-h")
      parse_shard(argv, options)
      options
    end

    def parse_minitest_flags!(argv)
      return [] if argv.grep(/\A-/).none?

      require "minitest"
      orig_argv = argv.dup

      Minitest.load_plugins unless argv.delete("--no-plugins") || ENV["MT_NO_PLUGINS"]
      minitest_options = Minitest.process_args(argv)

      minitest_args = Shellwords.split(minitest_options[:args] || "")
      remove_seed_flag(minitest_args) unless orig_argv.include?("--seed")

      minitest_args
    end

    def split(array, delim)
      delim_at = array.index(delim)
      return [array.dup, []] if delim_at.nil?

      [
        array[0...delim_at],
        array[(delim_at + 1)..]
      ]
    end

    def parse_shard(argv, options)
      argv.delete_if { |arg| options[:shard] = Regexp.last_match(1) if arg =~ /\A--shard=(.*)/ }

      argv.each_with_index do |flag, i|
        value = argv[i + 1]
        next unless flag == "--shard"
        raise "missing shard value" if value.nil? || value.start_with?("-")

        options[:shard] = value
        argv.slice!(i, 2)
        break
      end
    end

    def remove_seed_flag(parsed_argv)
      index = parsed_argv.index("--seed")
      parsed_argv.slice!(index, 2) if index
    end
  end
end
