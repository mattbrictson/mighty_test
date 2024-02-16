CLIResult = Struct.new(:stdout, :stderr, :exitstatus) do
  def success?
    exitstatus == 0 || exitstatus == true
  end

  def failure?
    !success?
  end
end
