require 'test/unit'
require "test/unit/version"
require "test/unit/collector/load"
require "json"
require "pathname"
require "vscode/test-unit/test_case_util"
require "vscode/test-unit/tests"
require "test/unit/ui/console/testrunner"
require "stringio"

Test::Unit::AutoRunner.need_auto_run = false

module VSCode
  module Test
    module Unit
      class Listener
        attr_reader :io
        attr_reader :current_test_case
        attr_reader :test_cases

        include TestCaseUtil

        def initialize(io:)
          @io = io
          @current_test_case = nil
          @test_cases = []
        end

        def attach_to_mediator(mediator)
          mediator.add_listener(::Test::Unit::TestResult::FAULT) do |fault|
            case fault
            when ::Test::Unit::Omission, ::Test::Unit::Pending
              io.print "\nPENDING: #{test_case_id(current_test_case)}\n"
            else
              io.print "\nFAILED: #{test_case_id(current_test_case)}\n"
            end

            test_cases << [current_test_case, fault]
            @current_test_case = nil
          end
          mediator.add_listener(::Test::Unit::TestCase::STARTED_OBJECT) do |test_case|
            @current_test_case = test_case
            io.print "\nRUNNING: #{test_case_id(current_test_case)}\n"
          end
          mediator.add_listener(::Test::Unit::TestCase::FINISHED_OBJECT) do |test_case|
            if test_case.passed?
              if test_case.equal?(current_test_case)
                test_cases << [test_case, nil]
                io.print "\nPASSED: #{test_case_id(test_case)}\n"
              end
            end
          end
        end
      end

      class <<self
        include TestCaseUtil

        def test_dir
          @test_dir ||= begin
            ENV.fetch("TESTS_DIR", "test")
          end
        end

        def list(io = $stdout)
          io.sync = true if io.respond_to?(:"sync=")
          tests = Tests.new(dir: test_dir, patterns: ENV["TESTS_PATTERN"])
          tests.load_all()
          data = {
            version: ::Test::Unit::VERSION,
            examples: tests.tests_from_suite
          }
          json = ENV.key?("PRETTY") ? JSON.pretty_generate(data) : JSON.generate(data)
          io.puts "START_OF_TEST_JSON#{json}END_OF_TEST_JSON"
        end

        def run(*args, io: $stdout)
          tests = Tests.new(dir: test_dir, patterns: ENV["TESTS_PATTERN"])
          tests.load_suites(args)

          started_at = Time.now

          runner = ::Test::Unit::UI::Console::TestRunner.new(
            tests.suite,
            output: StringIO.new
          )

          listener = Listener.new(io: io)
          runner.listeners << listener

          result = runner.start()

          examples = listener.test_cases.map do |test_case, fault|
            method_name = test_case.method_name
            path, line = test_case.class.instance_method(method_name.to_sym).source_location
            path = Pathname(path).realpath
            relative_path = path.relative_path_from(VSCode.project_root)
            id = test_case_id(test_case)

            common = {
              description: test_case.local_name,
              full_description: test_case.description,
              file_path: "./#{relative_path}",
              full_path: path,
              line_number: line,
              klass: test_case.class.name,
              runnable: test_case.class.name,
              id: id,
            }

            if test_case.passed? && !fault
              common.merge!(status: "passed")
            else
              case fault
              when ::Test::Unit::Failure
                common.merge!(
                  {
                    status: "failed",
                    exception: {
                      class: fault.class.name,
                      message: fault.message,
                      backtrace: fault.location,
                      full_backtrace: fault.location,
                      position: line_of_trace(fault.location, relative_path, method_name: test_case.method_name)
                    }
                  }
                )
              when ::Test::Unit::Pending
                common.merge!(
                  {
                    status: "failed",
                    pending_message: "Pending: #{fault.message}"
                  }
                )
              when ::Test::Unit::Omission
                common.merge!(
                  {
                    status: "failed",
                    pending_message: "Omission: #{fault.message}"
                  }
                )
              when ::Test::Unit::Error
                common.merge!(
                  {
                    status: "failed",
                    pending_message: nil,
                    exception: {
                      class: fault.exception.class.name,
                      message: fault.message,
                      backtrace: fault.location,
                      full_backtrace: fault.exception.backtrace,
                      position: line_of_trace(fault.location, relative_path, method_name: test_case.method_name)
                    }
                  }
                )
              end
            end
          end

          duration = Time.now - started_at
          runs = result.run_count
          failures = result.failures.size
          pendings = result.pendings.size + result.omissions.size
          errors = result.errors.size

          data = {
            version: ::Test::Unit::VERSION,
            examples: examples.compact,
            summary: {
              duration: duration,
              example_count: runs,
              failure_count: failures,
              pending_count: pendings,
              errors_outside_of_examples_count: errors
            },
            summary_line: "Total time: #{duration}, Runs: #{runs}, Assertions: #{result.assertion_count}, Failures: #{failures}, Errors: #{errors}, Skips: #{pendings}",
          }

          json = ENV.key?("PRETTY") ? JSON.pretty_generate(data) : JSON.generate(data)
          io.puts "START_OF_TEST_JSON#{json}END_OF_TEST_JSON"
        end

        def line_of_trace(trace, file, method_name: nil)
          pattern =
            if method_name
              /#{Regexp.escape(file.basename.to_s)}:(\d+):in `(block (\(\d+ levels\) )?in )?#{Regexp.escape(method_name)}'/
            else
              /#{Regexp.escape(file.basename.to_s)}:(\d+):in\b/
            end

          trace.each do |t|
            if t =~ pattern
              return $1.to_i
            end
          end

          nil
        end
      end
    end
  end
end
