require "optparse"

module MightyTest
  class OptionParser
    def initialize
      @parser = ::OptionParser.new do |op|
        op.require_exact = true
        op.banner = <<~BANNER
          Usage: mt
                 mt [test file...] [test dir...]
                 mt --watch

        BANNER

        op.on("--watch") { options[:watch] = true }
        op.on("--shard SHARD") { |value| options[:shard] = value }
        op.on("-h", "--help") { options[:help] = true }
        op.on("--version") { options[:version] = true }
      end
    end

    def parse(argv)
      @options = {}
      done = false
      extra_args = []
      argv, literal_args = split(argv, "--")

      until done
        orig_argv = argv.dup
        begin
          parser.parse!(argv)
          done = true
        rescue ::OptionParser::InvalidOption => e
          invalid = e.args.first
          extra_args << invalid
          orig_argv.delete_at(orig_argv.index(invalid))
          argv = orig_argv
        end
      end

      [argv + literal_args, extra_args, options]
    end

    def to_s
      parser.to_s
    end

    private

    attr_reader :options, :parser

    def split(array, delim)
      delim_at = array.index(delim)
      return [array.dup, []] if delim_at.nil?

      [
        array[0...delim_at],
        array[(delim_at + 1)..]
      ]
    end
  end
end
