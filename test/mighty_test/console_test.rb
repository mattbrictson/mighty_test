require "test_helper"

module MightyTest
  class ConsoleTest < Minitest::Test
    def test_clear_returns_false_if_not_tty
      result = nil
      capture_io { result = Console.new.clear }
      refute result
    end

    def test_clear_clears_the_screen_and_returns_true_and_if_tty
      result = nil
      stdout, = capture_io do
        $stdout.define_singleton_method(:tty?) { true }
        $stdout.define_singleton_method(:clear_screen) { print "clear!" }
        result = Console.new.clear
      end

      assert result
      assert_equal "clear!", stdout
    end

    def test_wait_for_keypress_returns_the_next_character_on_stdin
      console = Console.new(stdin: StringIO.new("hi"))

      assert_equal "h", console.wait_for_keypress
    end

    def test_play_sound_returns_false_if_not_tty
      result = nil
      capture_io { result = Console.new.play_sound(:pass) }
      refute result
    end

    def test_play_sound_returns_false_if_player_is_not_executable
      result = nil
      capture_io do
        $stdout.define_singleton_method(:tty?) { true }
        console = Console.new(sound_player: "/path/to/nothing")
        result = console.play_sound(:pass)
      end
      refute result
    end

    def test_play_sound_returns_false_if_sound_files_are_missing
      result = nil
      capture_io do
        $stdout.define_singleton_method(:tty?) { true }
        console = Console.new(sound_player: "/bin/echo", sound_paths: { pass: ["/path/to/nothing"] })
        result = console.play_sound(:pass)
      end
      refute result
    end

    def test_play_sound_raises_argument_error_if_invalid_sound_name_is_specified
      capture_io do
        $stdout.define_singleton_method(:tty?) { true }
        assert_raises(ArgumentError) { Console.new.play_sound(:whatever) }
      end
    end

    def test_play_sound_calls_sound_player_with_matching_sound_path
      result = nil
      stdout, = capture_subprocess_io do
        $stdout.define_singleton_method(:tty?) { true }
        console = Console.new(sound_player: "/bin/echo", sound_paths: { pass: [__FILE__] })
        result = console.play_sound(:pass, wait: true)
      end
      assert result
      assert_equal __FILE__, stdout.chomp
    end
  end
end
