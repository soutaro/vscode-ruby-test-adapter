$LOAD_PATH << File.expand_path(__dir__)
require "vscode"

VSCode::Minitest.run(*ARGV)
