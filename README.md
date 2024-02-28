# mighty_test

[![Gem Version](https://img.shields.io/gem/v/mighty_test)](https://rubygems.org/gems/mighty_test)
[![Gem Downloads](https://img.shields.io/gem/dt/mighty_test)](https://www.ruby-toolbox.com/projects/mighty_test)
[![GitHub Workflow Status](https://img.shields.io/github/actions/workflow/status/mattbrictson/mighty_test/ci.yml)](https://github.com/mattbrictson/mighty_test/actions/workflows/ci.yml)
[![Code Climate maintainability](https://img.shields.io/codeclimate/maintainability/mattbrictson/mighty_test)](https://codeclimate.com/github/mattbrictson/mighty_test)

mighty_test (`mt`) is a TDD-friendly Minitest runner for Ruby projects. It includes a Jest-inspired interactive watch mode, focus mode, CI sharding, run by directory/file/line number, fail-fast, and color formatting.

---

**Quick Start**

- [Install](#install)
- [Requirements](#requirements)
- [Usage](#usage)

**Features**

- ⚙️ [CI Mode](#%EF%B8%8F-ci-mode)
- 🧑‍🔬 [Watch Mode](#-watch-mode)
- 🔬 [Focus Mode](#-focus-mode)
- 🛑 [Fail Fast](#-fail-fast)
- 🚥 [Color Output](#-color-output)
- 💬 [More Options](#-more-options)

**Community**

- [Support](#support)
- [License](#license)
- [Code of conduct](#code-of-conduct)
- [Contribution guide](#contribution-guide)

## Install

The mighty_test gem provides an `mt` binary. To install it into a Ruby project, first add the gem to your Gemfile and run `bundle install`.

```ruby
gem "mighty_test"
```

Then generate a binstub:

```sh
bundle binstub mighty_test
```

Now you can run mighty_test with `bin/mt`.

> [!TIP]
> **When installing mighty_test in a Rails project, make sure to put the gem in the `:test` Gemfile group.** Although Rails has a built-in test runner (`bin/rails test`) that already provides a lot of what mighty_test offers, you can still use `bin/mt` with Rails projects for its unique `--watch` mode and CI `--shard` feature.

## Rake Integration (Non-Rails)

For non-Rails projects, `rake test` is the popular convention for running tests. To provide an easy migration path to `mt`, you can make the following change to your Rakefile.

First, remove any existing `Rake::TestTask` from your Rakefile. Then add the following snippet:

```ruby
require "shellwords"

desc "Run all tests, excluding slow tests"
task :test do
  sh "bin/mt", *Shellwords.split(ENV["TESTOPTS"] || ""), "--", *Array(ENV["TEST"]),
end

desc "Run all tests, slow tests included"
task :"test:all" do
  sh "bin/mt", "--all", *Shellwords.split(ENV["TESTOPTS"] || "")
end
```

## Requirements

mighty_test requires modern versions of Minitest and Ruby.

- Minitest 5.15+
- Ruby 3.1+

Support for older Ruby versions will be dropped when they reach EOL. The EOL schedule can be found here: https://endoflife.date/ruby

> [!NOTE]
> mighty_test currently assumes that your tests are stored in `test/` and are named `*_test.rb`. Watch mode expects implementation files to be in `app/` and/or `lib/`.

## Usage

`mt` defaults to running all tests, excluding slow tests (see the explanation of slow tests below). You can also run tests by directory, file, or line number.

```sh
# Run all tests, excluding slow tests
bin/mt

# Run all tests, slow tests included
bin/mt --all

# Run a specific test file
bin/mt test/cli_test.rb

# Run a test by line number
bin/mt test/importer_test.rb:43

# Run a directory of tests
bin/mt test/commands
```

> [!TIP]
> mighty_test is optimized for TDD, and excludes slow tests by default. **Slow tests** are defined as those found in `test/{e2e,feature,features,integration,system}` directories. You can run slow tests with `--all` or by specifying a slow test file or directory explicitly, like `bin/mt test/system`.

## ⚙️ CI Mode

If the `CI` environment variable is set, mighty_test defaults to running _all_ tests, including slow tests. This is equivalent to passing `--all`.

mighty_test can also distribute test files evenly across parallel CI jobs, using the `--shard` option. The _shard_ nomenclature has been borrowed from similar features in [Jest](https://jestjs.io/docs/cli#--shard) and [Playwright](https://playwright.dev/docs/test-sharding).

```sh
# Run the 1st group of tests out of 4 total groups
bin/mt --shard 1/4
```

In GitHub Actions, for example, you can use `--shard` with a matrix strategy to easily divide tests across N jobs.

```yaml
jobs:
  test:
    strategy:
      matrix:
        shard:
          - "1/4"
          - "2/4"
          - "3/4"
          - "4/4"
    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true
      - run: bin/mt --shard ${{ matrix.shard }}
```

In CircleCI, you can use the `parallelism` setting, which automatically injects `$CIRCLE_NODE_INDEX` and `$CIRCLE_NODE_TOTAL` environment variables. Note that `$CIRCLE_NODE_INDEX` is zero-indexed, so it needs to be incremented by 1.

```yaml
jobs:
  test:
    parallelism: 4
    steps:
      - checkout
      - ruby/install-deps
      - run: SHARD="$((${CIRCLE_NODE_INDEX}+1))"; bin/mt --shard ${SHARD}/${CIRCLE_NODE_TOTAL}
```

> [!TIP]
> `--shard` will shuffle tests and automatically distribute slow tests evenly across jobs.

## 🧑‍🔬 Watch Mode

mighty_test includes a Jest-style watch mode, which can be started with `--watch`. This is ideal for TDD.

```sh
# Start watch mode
bin/mt --watch
```

In watch mode, mighty_test will listen for file system activity and run a test file whenever it is modified.

When you modify an implementation file, mighty_test will find the corresponding test file and run it automatically. This works as long as your implementation and test files follow a standard path naming convention: e.g. `lib/commands/init.rb` is expected to have a corresponding test file named `test/commands/init_test.rb`.

Watch mode also offers a menu of interactive commands:

```
> Press Enter to run all tests.
> Press "a" to run all tests, including slow tests.
> Press "d" to run tests for files diffed or added since the last git commit.
> Press "h" to show this help menu.
> Press "q" to quit.
```

## 🔬 Focus Mode

You can focus a specific test by annotating the method definition with `focus`.

```ruby
class MyTest < Minitest::Test
  focus def test_something_important
    assert # ...
  end
```

Now running `bin/mt` will execute only the focused test:

```sh
# Only runs MyTest#test_something_important
bin/mt
```

In Rails projects that use the `test` syntax, `focus` must be placed on the previous line.

```ruby
class MyTest < ActiveSupport::TestCase
  focus
  test "something important" do
    assert # ...
  end
```

This functionality is provided by the [minitest-focus](https://github.com/minitest/minitest-focus) plugin, which is included with mighty_test.

## 🛑 Fail Fast

By default, mighty_test runs the entire test suite to completion. With the `--fail-fast` option, it will stop on the first failed test.

```sh
# Stop immediately on first test failure
bin/mt --fail-fast

# Use with watch mode for even faster TDD
bin/mt --watch --fail-fast
```

This functionality is provided by the [minitest-fail-fast](https://github.com/teoljungberg/minitest-fail-fast) plugin, which is included with mighty_test.

## 🚥 Color Output

Successes, failures, errors, and skips are colored appropriately by default.

```sh
# Run tests with color output (if terminal supports it)
bin/mt

# Disable color
bin/mt --no-rg
```

(image goes here)

This functionality is provided by the [minitest-rg](https://github.com/minitest/minitest-rg) plugin, which is included with mighty_test.

## 💬 More Options

Minitest options are passed through to Minitest.

```sh
# Run tests with Minitest pride color output
bin/mt --pride

# Run tests with an explicit seed value for test ordering
bin/mt --seed 4519

# Run tests with detailed progress and explanation of skipped tests
bin/mt --verbose

# Show the full list of possible options
bin/mt --help
```

When using the Rake integration, Rake-style test environment variables still work. These are equivalent:

```sh
# Rake style
rake test TEST=test/commands/init_test.rb TESTOPTS=--verbose

# CLI style
bin/mt --verbose test/commands/init_test.rb
```

## Support

If you want to report a bug, or have ideas, feedback or questions about the gem, [let me know via GitHub issues](https://github.com/mattbrictson/mighty_test/issues/new) and I will do my best to provide a helpful answer. Happy hacking!

## License

The gem is available as open source under the terms of the [MIT License](LICENSE.txt).

## Code of conduct

Everyone interacting in this project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](CODE_OF_CONDUCT.md).

## Contribution guide

Pull requests are welcome!
