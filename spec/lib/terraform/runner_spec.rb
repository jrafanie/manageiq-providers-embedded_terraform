require 'webmock/rspec'
require 'json'

RSpec.describe(Terraform::Runner) do
  describe "is .available" do
    before do
      ENV["TERRAFORM_RUNNER_URL"] = "https://1.2.3.4:7000"

      stub_request(:get, "https://1.2.3.4:7000/api/terraformjobs/count")
        .to_return(:status => 200, :body => {'count' => 0}.to_json)
    end

    it "check if terraform-runner service is available" do
      expect(Terraform::Runner.available?).to(be(true))
    end
  end

  describe ".run" do
    let(:input_vars) { {} }

    let(:create_response) { JSON.parse(File.read(File.join(__dir__, "runner/data/responses/hello-world-create-success.json"))) }
    let(:retrieve_response) { JSON.parse(File.read(File.join(__dir__, "runner/data/responses/hello-world-retrieve-success.json"))) }

    before do
      ENV["TERRAFORM_RUNNER_URL"] = "https://1.2.3.4:7000"

      stub_request(:post, "https://1.2.3.4:7000/api/stack/create")
        .to_return(
          :status => 200,
          :body   => create_response.to_json
        )

      stub_request(:post, "https://1.2.3.4:7000/api/stack/retrieve")
        .to_return(
          :status => 200,
          :body   => retrieve_response.to_json
        )
    end

    it "runs a hello-world terraform template" do
      response = Terraform::Runner.run(input_vars, File.join(__dir__, "runner/data/hello-world"))

      expect(response.status).to(eq('SUCCESS'), "terraform-runner failed with:\n#{response.status}")
      expect(response.message).to(include('greeting = "Hello World"'))
      expect(response.stack_id).to(eq(retrieve_response['stack_id']))
      expect(response.action).to(eq('CREATE'))
      expect(response.stack_name).to(eq(retrieve_response['stack_name']))
      expect(response.details.keys).to(eq(%w[resources outputs]))
    end
  end
end
