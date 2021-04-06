$LOAD_PATH << File.expand_path(__dir__)

module VSCode
  autoload :Minitest, "vscode/minitest"
  autoload :Test, "vscode/test-unit"

  module_function

  def project_root
    @project_root ||= Pathname.new(Dir.pwd)
  end
end
