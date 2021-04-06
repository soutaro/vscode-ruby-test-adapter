require_relative "test_helper"

FILES = {}

FILES["Rakefile"] = <<RUBY
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList['test/**/*_test.rb']
end
RUBY
FILES["lib/square.rb"] = <<RUBY
class Square
  def square_of(n)
    n * n
  end
end
RUBY
FILES["test/test_helper.rb"] = <<RUBY
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require "square"
require "test/unit"

module TestHelper
end
RUBY
FILES["test/square_test.rb"] = <<RUBY
require_relative "test_helper"

class SquareTest < Test::Unit::TestCase
  def test_square_of_one
    assert_equal 1, Square.new.square_of(1)
  end

  def test_square_of_two
    assert_equal 3, Square.new.square_of(2)
  end

  def test_square_error
    raise
  end

  def test_square_omit
    omit "This is omitted"
  end

  def test_square_pend
    pend "This is pending"
  end
end
RUBY

class RakeTaskTest < Test::Unit::TestCase
  include TestHelper

  attr_reader :dir

  def setup
    super
    @dir = Pathname(Dir.mktmpdir).realpath

    FILES.each do |path, content|
      path = dir + path

      path.parent.mkpath unless path.parent.directory?
      path.write(content)
    end
  end

  def env
    {
      "TESTS_DIR" => "./test/",
      "TESTS_PATTERN" => "*_test.rb,test_*.rb"
    }
  end

  def json_output(string)
    assert_match /START_OF_TEST_JSON(.*)END_OF_TEST_JSON/, string

    string =~ /START_OF_TEST_JSON(.*)END_OF_TEST_JSON/
    JSON.parse($1, symbolize_names: true)
  end

  def test_list
    stdout, stderr, status = Open3.capture3(env, "rake -R #{__dir__}/../.. vscode:test-unit:list", chdir: dir.to_s)

    assert_predicate status, :success?

    json = json_output(stdout)
    examples = json[:examples]

    assert_equal 5, examples.size

    assert_any(examples, pass_count: 1) do |example|
      assert_equal(
        {
          description: "test_square_error",
          full_description: "test_square_error(SquareTest)",
          file_path: "./test/square_test.rb",
          full_path: "#{dir}/test/square_test.rb",
          line_number: 12,
          klass: "SquareTest",
          runnable: "SquareTest",
          id: "./test/square_test.rb[12]:test_square_error"
        },
        example
      )
    end

    assert_any(examples, pass_count: 1) do |example|
      assert_equal(
        {
          description: "test_square_of_one",
          full_description: "test_square_of_one(SquareTest)",
          file_path: "./test/square_test.rb",
          full_path: "#{dir}/test/square_test.rb",
          line_number: 4,
          klass: "SquareTest",
          runnable: "SquareTest",
          id: "./test/square_test.rb[4]:test_square_of_one"
        },
        example
      )
    end

    assert_any(examples, pass_count: 1) do |example|
      assert_equal(
        {
          description: "test_square_of_two",
          full_description: "test_square_of_two(SquareTest)",
          file_path: "./test/square_test.rb",
          full_path: "#{dir}/test/square_test.rb",
          line_number: 8,
          klass: "SquareTest",
          runnable: "SquareTest",
          id: "./test/square_test.rb[8]:test_square_of_two"
        },
        example
      )
    end

    assert_any(examples, pass_count: 1) do |example|
      assert_equal(
        {
          description: "test_square_omit",
          full_description: "test_square_omit(SquareTest)",
          file_path: "./test/square_test.rb",
          full_path: "#{dir}/test/square_test.rb",
          line_number: 16,
          klass: "SquareTest",
          runnable: "SquareTest",
          id: "./test/square_test.rb[16]:test_square_omit"
        },
        example
      )
    end

    assert_any(examples, pass_count: 1) do |example|
      assert_equal(
        {
          description: "test_square_pend",
          full_description: "test_square_pend(SquareTest)",
          file_path: "./test/square_test.rb",
          full_path: "#{dir}/test/square_test.rb",
          line_number: 20,
          klass: "SquareTest",
          runnable: "SquareTest",
          id: "./test/square_test.rb[20]:test_square_pend"
        },
        example
      )
    end
  end

  def test_run_success
    stdout, stderr, status = Open3.capture3(env, "rake -R #{__dir__}/../.. vscode:test-unit:run ./test/square_test.rb:4", chdir: dir.to_s)

    assert_match /RUNNING: \.\/test\/square_test\.rb\[4\]:test_square_of_one/, stdout
    assert_match /PASSED: \.\/test\/square_test\.rb\[4\]:test_square_of_one/, stdout

    json = json_output(stdout)
    examples = json[:examples]

    assert_equal 1, examples.size

    examples[0].tap do |example|
      assert_equal "./test/square_test.rb[4]:test_square_of_one", example[:id]
      assert_equal "test_square_of_one", example[:description]
      assert_equal "test_square_of_one(SquareTest)", example[:full_description]
      assert_equal "./test/square_test.rb", example[:file_path]
      assert_equal "#{dir}/test/square_test.rb", example[:full_path]
      assert_equal 4, example[:line_number]
      assert_equal "SquareTest", example[:klass]
      assert_equal "SquareTest", example[:runnable]
      assert_equal "passed", example[:status]
      assert_nil example[:exception]
      assert_nil example[:pending_message]
    end
  end

  def test_run_fail
    stdout, stderr, status = Open3.capture3(env, "rake -R #{__dir__}/../.. vscode:test-unit:run ./test/square_test.rb:8", chdir: dir.to_s)

    assert_match /RUNNING: \.\/test\/square_test\.rb\[8\]:test_square_of_two/, stdout
    assert_match /FAILED: \.\/test\/square_test\.rb\[8\]:test_square_of_two/, stdout

    json = json_output(stdout)
    examples = json[:examples]

    assert_equal 1, examples.size

    examples[0].tap do |example|
      assert_equal "./test/square_test.rb[8]:test_square_of_two", example[:id]
      assert_equal "test_square_of_two", example[:description]
      assert_equal "test_square_of_two(SquareTest)", example[:full_description]
      assert_equal "./test/square_test.rb", example[:file_path]
      assert_equal "#{dir}/test/square_test.rb", example[:full_path]
      assert_equal 8, example[:line_number]
      assert_equal "SquareTest", example[:klass]
      assert_equal "SquareTest", example[:runnable]
      assert_equal "failed", example[:status]
      assert_instance_of Hash, example[:exception]
      example[:exception].tap do |exn|
        assert_equal "Test::Unit::Failure", exn[:class]
        assert_equal "<3> expected but was\n<4>.", exn[:message]
        assert_equal 9, exn[:position]
        assert_instance_of Array, exn[:backtrace]
        assert_instance_of Array, exn[:full_backtrace]
      end
      assert_nil example[:pending_message]
    end
  end

  def test_run_error
    stdout, stderr, status = Open3.capture3(env, "rake -R #{__dir__}/../.. vscode:test-unit:run ./test/square_test.rb:12", chdir: dir.to_s)

    assert_match /RUNNING: \.\/test\/square_test\.rb\[12\]:test_square_error/, stdout
    assert_match /FAILED: \.\/test\/square_test\.rb\[12\]:test_square_error/, stdout

    json = json_output(stdout)
    examples = json[:examples]

    assert_equal 1, examples.size

    examples[0].tap do |example|
      assert_equal "./test/square_test.rb[12]:test_square_error", example[:id]
      assert_equal "test_square_error", example[:description]
      assert_equal "test_square_error(SquareTest)", example[:full_description]
      assert_equal "./test/square_test.rb", example[:file_path]
      assert_equal "#{dir}/test/square_test.rb", example[:full_path]
      assert_equal 12, example[:line_number]
      assert_equal "SquareTest", example[:klass]
      assert_equal "SquareTest", example[:runnable]
      assert_equal "failed", example[:status]
      assert_instance_of Hash, example[:exception]
      example[:exception].tap do |exn|
        assert_equal "RuntimeError", exn[:class]
        assert_equal "RuntimeError: ", exn[:message]
        assert_equal 13, exn[:position]
        assert_instance_of Array, exn[:backtrace]
        assert_instance_of Array, exn[:full_backtrace]
      end
      assert_nil example[:pending_message]
    end
  end

  def test_run_omit
    stdout, stderr, status = Open3.capture3(env, "rake -R #{__dir__}/../.. vscode:test-unit:run ./test/square_test.rb:16", chdir: dir.to_s)

    assert_match /RUNNING: \.\/test\/square_test\.rb\[16\]:test_square_omit/, stdout
    assert_match /PENDING: \.\/test\/square_test\.rb\[16\]:test_square_omit/, stdout

    json = json_output(stdout)
    examples = json[:examples]

    assert_equal 1, examples.size

    examples[0].tap do |example|
      assert_equal "./test/square_test.rb[16]:test_square_omit", example[:id]
      assert_equal "test_square_omit", example[:description]
      assert_equal "test_square_omit(SquareTest)", example[:full_description]
      assert_equal "./test/square_test.rb", example[:file_path]
      assert_equal "#{dir}/test/square_test.rb", example[:full_path]
      assert_equal 16, example[:line_number]
      assert_equal "SquareTest", example[:klass]
      assert_equal "SquareTest", example[:runnable]
      assert_equal "failed", example[:status]
      assert_nil example[:exception]
      assert_equal "Omission: This is omitted", example[:pending_message]
    end
  end

  def test_run_pend
    stdout, stderr, status = Open3.capture3(env, "rake -R #{__dir__}/../.. vscode:test-unit:run ./test/square_test.rb:20", chdir: dir.to_s)

    assert_match /RUNNING: \.\/test\/square_test\.rb\[20\]:test_square_pend/, stdout
    assert_match /PENDING: \.\/test\/square_test\.rb\[20\]:test_square_pend/, stdout

    json = json_output(stdout)
    examples = json[:examples]

    assert_equal 1, examples.size

    examples[0].tap do |example|
      assert_equal "./test/square_test.rb[20]:test_square_pend", example[:id]
      assert_equal "test_square_pend", example[:description]
      assert_equal "test_square_pend(SquareTest)", example[:full_description]
      assert_equal "./test/square_test.rb", example[:file_path]
      assert_equal "#{dir}/test/square_test.rb", example[:full_path]
      assert_equal 20, example[:line_number]
      assert_equal "SquareTest", example[:klass]
      assert_equal "SquareTest", example[:runnable]
      assert_equal "failed", example[:status]
      assert_nil example[:exception]
      assert_equal "Pending: This is pending", example[:pending_message]
    end
  end

  def test_run_file
    stdout, stderr, status = Open3.capture3(env, "rake -R #{__dir__}/../.. vscode:test-unit:run ./test/square_test.rb", chdir: dir.to_s)

    assert_match /RUNNING: \.\/test\/square_test\.rb\[20\]:test_square_pend/, stdout
    assert_match /PENDING: \.\/test\/square_test\.rb\[20\]:test_square_pend/, stdout

    json = json_output(stdout)
    examples = json[:examples]

    assert_equal 5, examples.size
    assert_equal 5, examples.count {|example| example.key?(:status) }
  end
end
