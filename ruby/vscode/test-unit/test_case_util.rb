module VSCode
  module Test
    module Unit
      module TestCaseUtil
        def test_case_id(test_case)
          method_name = test_case.method_name
          path, line = test_case.class.instance_method(method_name.to_sym).source_location
          path = Pathname(path).realpath
          relative_path = path.relative_path_from(VSCode.project_root)

          "./#{relative_path}[#{line}]:#{test_case.local_name}"
        end
      end
    end
  end
end
