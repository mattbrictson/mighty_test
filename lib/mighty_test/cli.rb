require "thor"

module MightyTest
  class CLI < Thor
    extend ThorExt::Start

    map %w[-v --version] => "version"

    desc "version", "Display mighty_test version", hide: true
    def version
      say "mighty_test/#{VERSION} #{RUBY_DESCRIPTION}"
    end
  end
end
