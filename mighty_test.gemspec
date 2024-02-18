require_relative "lib/mighty_test/version"

Gem::Specification.new do |spec|
  spec.name = "mighty_test"
  spec.version = MightyTest::VERSION
  spec.authors = ["Matt Brictson"]
  spec.email = ["opensource@mattbrictson.com"]

  spec.summary = "A modern Minitest runner for TDD, with watch mode and more"
  spec.homepage = "https://github.com/mattbrictson/mighty_test"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata = {
    "bug_tracker_uri" => "https://github.com/mattbrictson/mighty_test/issues",
    "changelog_uri" => "https://github.com/mattbrictson/mighty_test/releases",
    "source_code_uri" => "https://github.com/mattbrictson/mighty_test",
    "homepage_uri" => spec.homepage,
    "rubygems_mfa_required" => "true"
  }

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.glob(%w[LICENSE.txt README.md {exe,lib}/**/*]).reject { |f| File.directory?(f) }
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "concurrent-ruby", "~> 1.1"
  spec.add_dependency "listen", "~> 3.5"
  spec.add_dependency "minitest", "~> 5.15"
  spec.add_dependency "minitest-fail-fast", "~> 0.1.0"
  spec.add_dependency "minitest-focus", "~> 1.4"
  spec.add_dependency "minitest-rg", "~> 5.3"
end
