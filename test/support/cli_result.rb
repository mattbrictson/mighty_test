CLIResult = Struct.new(:stdout, :stderr, :exitstatus) do
  def success?
    [0, true].include?(exitstatus)
  end

  def failure?
    !success?
  end
end
