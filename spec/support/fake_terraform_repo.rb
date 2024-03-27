module Spec
  module Support
    class FakeTerraformRepo < Spec::Support::FakeGitRepo
      private

      def file_content(full_path)
      end
    end
  end
end
