require "io/console"
require "io/wait"

module MightyTest
  class Console
    def initialize(stdin: $stdin, sound_player: "/usr/bin/afplay", sound_paths: SOUNDS)
      @stdin = stdin
      @sound_player = sound_player
      @sound_paths = sound_paths
    end

    def clear
      return false unless tty?

      $stdout.clear_screen
      true
    end

    def with_raw_input(&)
      return yield unless stdin.respond_to?(:raw) && tty?

      stdin.raw(intr: true, &)
    end

    def read_keypress_nonblock
      stdin.getc if stdin.wait_readable(0)
    end

    def play_sound(name, wait: false)
      return false unless tty?

      paths = sound_paths.fetch(name) { raise ArgumentError, "Unknown sound name #{name}" }
      path = paths.find { |p| File.exist?(p) }
      return false unless path && File.executable?(sound_player)

      thread = Thread.new { system(sound_player, path) }
      thread.join if wait
      true
    end

    private

    # rubocop:disable Layout/LineLength
    SOUNDS = {
      pass: %w[
        /System/Library/PrivateFrameworks/ToneLibrary.framework/Versions/A/Resources/AlertTones/EncoreInfinitum/Milestone-EncoreInfinitum.caf
        /System/Library/Sounds/Glass.aiff
      ],
      fail: %w[
        /System/Library/PrivateFrameworks/ToneLibrary.framework/Versions/A/Resources/AlertTones/EncoreInfinitum/Rebound-EncoreInfinitum.caf
        /System/Library/Sounds/Bottle.aiff
      ]
    }.freeze
    private_constant :SOUNDS
    # rubocop:enable Layout/LineLength

    attr_reader :sound_player, :sound_paths, :stdin

    def tty?
      $stdout.respond_to?(:tty?) && $stdout.tty?
    end
  end
end
