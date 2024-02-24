module MightyTest
  class Sharder
    DEFAULT_SEED = 123_456_789

    def self.from_argv(value, env: ENV)
      index, total = value.to_s.match(%r{\A(\d+)/(\d+)\z})&.captures&.map(&:to_i)
      raise ArgumentError, "shard: value must be in the form INDEX/TOTAL (e.g. 2/8)" if total.nil?

      git_sha = env.values_at("GITHUB_SHA", "CIRCLE_SHA1").find { |sha| !sha.to_s.strip.empty? }
      seed = git_sha&.unpack1("l_")

      new(index:, total:, seed:)
    end

    attr_reader :index, :total, :seed

    def initialize(index:, total:, seed: nil)
      raise ArgumentError, "shard: total shards must be a number greater than 0" unless total > 0

      valid_group = index > 0 && index <= total
      raise ArgumentError, "shard: shard index must be > 0 and <= #{total}" unless valid_group

      @index = index
      @total = total
      @seed = seed || DEFAULT_SEED
    end

    def shard(*test_paths)
      random = Random.new(seed)
      shuffled_paths = test_paths.flatten.shuffle(random:)
      slices = shuffled_paths.each_slice(total)
      slices.filter_map { |slice| slice[index - 1] }
    end
  end
end
