module VSCode
  module Test
    module Unit
      class Tests
        include TestCaseUtil

        attr_reader :dir, :patterns
        attr_reader :suite

        def initialize(dir:, patterns:)
          @dir = dir
          @patterns = patterns
        end

        def load_all
          collector = ::Test::Unit::Collector::Load.new()
          collector.base = VSCode.project_root
          collector.patterns.replace(file_patterns) if file_patterns

          @suite = collector.collect(dir)
        end

        def all
          load_all unless @suite
          tests_from_suite()
        end

        def tests_from_suite(suite = self.suite, tests: [])
          suite.tests.each do |test|
            case test
            when ::Test::Unit::TestSuite
              tests_from_suite(test, tests: tests)
            when ::Test::Unit::TestCase
              method_name = test.method_name
              path, line = test.class.instance_method(method_name.to_sym).source_location
              path = Pathname(path).realpath
              relative_path = path.relative_path_from(VSCode.project_root)
              tests << {
                description: test.local_name,
                full_description: test.description,
                file_path: "./#{relative_path}",
                full_path: path,
                line_number: line,
                klass: test.class.name,
                runnable: test.class.name,
                id: test_case_id(test)
              }
            end
          end

          tests
        end

        def file_patterns
          if patterns
            patterns.split(/,/).map do |pat|
              pat.gsub!('.', '\.')
              pat.gsub!('*', '.*')
              pat.gsub!('?', '.')
              pat.gsub!(/\[!([^\]]+)\]/) { "[^#{$1}]" }
              Regexp.compile(pat)
            end
          end
        end

        def load_suites(args)
          arg_pairs = args.map do |arg|
            path, line = arg.split(/:/)

            path = VSCode.project_root + path
            path = path.realpath.relative_path_from(VSCode.project_root)

            [path, line&.to_i]
          end

          files = arg_pairs.map {|arg| arg[0].to_s }.uniq()

          collector = ::Test::Unit::Collector::Load.new()
          collector.base = VSCode.project_root
          collector.patterns.replace(file_patterns) if file_patterns

          collector.filter = ->(test) {
            method_name = test.method_name

            full_path, method_line = test.class.instance_method(method_name.to_sym).source_location
            full_path = Pathname(full_path).realpath
            relative_path = full_path.relative_path_from(VSCode.project_root)

            arg_pairs.any? do |(path, line)|
              if relative_path == path
                if line
                  method_line == line
                else
                  true
                end
              end
            end
          }

          @suite = collector.collect(*files)
        end
      end
    end
  end
end
