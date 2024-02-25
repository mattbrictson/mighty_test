require "test_helper"

module MightyTest
  class SharderTest < Minitest::Test
    def test_it_parses_the_shard_value
      sharder = Sharder.from_argv("2/7")

      assert_equal(2, sharder.index)
      assert_equal(7, sharder.total)
    end

    def test_it_raises_an_exception_on_an_invalid_format
      error = assert_raises(ArgumentError) do
        Sharder.from_argv("a/9")
      end

      assert_includes(error.message, "value must be in the form INDEX/TOTAL")
    end

    def test_it_raises_an_exception_on_an_invalid_index_value
      error = assert_raises(ArgumentError) do
        Sharder.from_argv("9/5")
      end

      assert_includes(error.message, "index must be > 0 and <= 5")
    end

    def test_it_raises_an_exception_on_an_invalid_total_value
      error = assert_raises(ArgumentError) do
        Sharder.from_argv("1/0")
      end

      assert_includes(error.message, "total shards must be a number greater than 0")
    end

    def test_it_has_a_default_hardcoded_seed
      sharder = Sharder.from_argv("1/2", env: {})
      assert_equal(123_456_789, sharder.seed)
    end

    def test_it_derives_a_seed_value_from_the_github_actions_env_var
      sharder = Sharder.from_argv("1/2", env: { "GITHUB_SHA" => "b94d6d86a2281d690eafd7bb3282c7032999e85f" })
      assert_equal(3_906_982_861_516_061_026, sharder.seed)
    end

    def test_it_derives_a_seed_value_from_the_circle_ci_env_var
      sharder = Sharder.from_argv("1/2", env: { "CIRCLE_SHA1" => "189733eff795bd1ea7c586a5234a717f82e58b64" })
      assert_equal(7_378_359_859_579_271_217, sharder.seed)
    end

    def test_for_a_given_seed_it_generates_a_stable_shuffled_result
      sharder = Sharder.new(index: 1, total: 2, seed: 678)
      result = sharder.shard(%w[a b c d e f])

      assert_equal(%w[f e c], result)
    end

    def test_it_divides_items_into_roughly_equally_sized_shards
      all = %w[a b c d e f g h i j k l m n o p q r]
      shards = (1..4).map do |index|
        Sharder.new(index:, total: 4).shard(all)
      end

      shards.each do |shard|
        assert_includes [4, 5], shard.length
      end

      assert_equal all, shards.flatten.sort
    end

    def test_it_evenly_distributes_slow_paths_across_shards
      all = %w[
        test/system/login_test.rb
        test/system/admin_test.rb
        test/models/post_test.rb
        test/system/editor_test.rb
        test/models/user_test.rb
        test/system/email_test.rb
        test/models/comment_test.rb
        test/system/rss_test.rb
        test/models/category_test.rb
        test/system/moderation_test.rb
      ]
      shards = (1..3).map do |index|
        Sharder.new(index:, total: 3).shard(all)
      end

      assert_equal(
        [
          %w[
            test/models/user_test.rb
            test/models/post_test.rb
            test/system/login_test.rb
            test/system/admin_test.rb
          ],
          %w[
            test/models/comment_test.rb
            test/system/rss_test.rb
            test/system/moderation_test.rb
          ],
          %w[
            test/models/category_test.rb
            test/system/email_test.rb
            test/system/editor_test.rb
          ]
        ],
        shards
      )
    end
  end
end
