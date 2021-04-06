$LOAD_PATH << File.expand_path(__dir__)
require "vscode"

VSCode::Test::Unit.run(*ARGV)
exit(0)
