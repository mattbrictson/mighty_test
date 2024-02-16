module FixturesPath
  private

  def fixtures_path
    Pathname.new(File.expand_path("../fixtures", __dir__))
  end
end
