module MightyTest
  class Sharder
    DEFAULT_SEED = 123_456_789

    def self.from_argv(value, env: ENV, file_system: FileSystem.new)
      index, total = value.to_s.match(%r{\A(\d+)/(\d+)\z})&.captures&.map(&:to_i)
      raise ArgumentError, "shard: value must be in the form INDEX/TOTAL (e.g. 2/8)" if total.nil?

      git_sha = env.values_at("GITHUB_SHA", "CIRCLE_SHA1").find { |sha| !sha.to_s.strip.empty? }
      seed = git_sha&.unpack1("l_")

      new(index:, total:, seed:, file_system:)
    end

    attr_reader :index, :total, :seed

    def initialize(index:, total:, seed: nil, file_system: FileSystem.new)
      raise ArgumentError, "shard: total shards must be a number greater than 0" unless total > 0

      valid_group = index > 0 && index <= total
      raise ArgumentError, "shard: shard index must be > 0 and <= #{total}" unless valid_group

      @index = index
      @total = total
      @seed = seed || DEFAULT_SEED
      @file_system = file_system
    end

    def shard(*test_paths)
      random = Random.new(seed)

      # Shuffle slow and normal paths separately so that slow ones get evenly distributed
      shuffled_paths = test_paths
        .flatten
        .partition { |path| !file_system.slow_test_path?(path) }
        .flat_map { |paths| paths.shuffle(random:) }

      slices = shuffled_paths.each_slice(total)
      slices.filter_map { |slice| slice[index - 1] }
    end

    private

    attr_reader :file_system
  end
end
