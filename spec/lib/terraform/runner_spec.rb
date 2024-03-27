require 'webmock/rspec'
require 'json'

RSpec.describe(Terraform::Runner) do
  before(:all) do
    @hello_world_create_response = JSON.parse(File.read(File.join(__dir__, "runner/data/responses/hello-world-create-success.json")))
    @hello_world_retrieve_response = JSON.parse(File.read(File.join(__dir__, "runner/data/responses/hello-world-retrieve-success.json")))
  end

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

  describe ".run hello-world with no input vars ( nil argument )" do
    let(:input_vars) { nil }

    before do
      ENV["TERRAFORM_RUNNER_URL"] = "https://1.2.3.4:7000"

      stub_request(:post, "https://1.2.3.4:7000/api/stack/create")
        .with(:body => hash_including({:parameters => []}))
        .to_return(
          :status => 200,
          :body   => @hello_world_create_response.to_json
        )

      stub_request(:post, "https://1.2.3.4:7000/api/stack/retrieve")
        .with(:body => hash_including({:stack_id => @hello_world_retrieve_response['stack_id']}))
        .to_return(
          :status => 200,
          :body   => @hello_world_retrieve_response.to_json
        )
    end

    it "runs a hello-world terraform template" do
      response = Terraform::Runner.run(input_vars, File.join(__dir__, "runner/data/hello-world"))

      expect(response.status).to(eq('SUCCESS'), "terraform-runner failed with:\n#{response.status}")
      expect(response.message).to(include('greeting = "Hello World"'))
      expect(response.stack_id).to(eq(@hello_world_retrieve_response['stack_id']))
      expect(response.action).to(eq('CREATE'))
      expect(response.stack_name).to(eq(@hello_world_retrieve_response['stack_name']))
      expect(response.details.keys).to(eq(%w[resources outputs]))
    end
  end

  describe ".run hello-world with input_vars" do
    let(:input_vars) { {:name => 'Mumbai'} }

    def verify_request_and_respond(request)
      body = JSON.parse(request.body)

      # verify parameters
      expect(body['parameters'].length).to(eq(1))
      data = body['parameters'][0]
      expect(data['name']).to(eq('name'))
      expect(data['value']).to(eq('Mumbai'))

      # verify other attributes
      expect(body['name']).not_to(be_empty)
      expect(body['tenantId']).not_to(be_empty)
      expect(body['templateZipFile']).not_to(be_empty)

      @hello_world_create_response.to_json
    end

    before do
      ENV["TERRAFORM_RUNNER_URL"] = "https://1.2.3.4:7000"

      stub_request(:post, "https://1.2.3.4:7000/api/stack/create")
        .to_return(->(request) { {:body => verify_request_and_respond(request)} })

      response = @hello_world_retrieve_response.clone
      response['message'] = response['message'].gsub('World', 'Mumbai')
      response['details']['outputs'][0]['value'] = response['details']['outputs'][0]['value'].sub('World', 'Mumbai')

      stub_request(:post, "https://1.2.3.4:7000/api/stack/retrieve")
        .with(:body => hash_including({:stack_id => @hello_world_retrieve_response['stack_id']}))
        .to_return(
          :status => 200,
          :body   => response.to_json
        )
    end

    it "runs a hello-world terraform template" do
      response = Terraform::Runner.run(input_vars, File.join(__dir__, "runner/data/hello-world"))

      expect(response.status).to(eq('SUCCESS'), "terraform-runner failed with:\n#{response.status}")
      expect(response.message).to(include('greeting = "Hello Mumbai"'))
      expect(response.stack_id).to(eq(@hello_world_retrieve_response['stack_id']))
      expect(response.action).to(eq('CREATE'))
      expect(response.stack_name).to(eq(@hello_world_retrieve_response['stack_name']))
      expect(response.details.keys).to(eq(%w[resources outputs]))
    end
  end

  context '.run_async hello-world' do
    describe '.run_async' do
      create_stub = nil
      retrieve_stub = nil

      before do
        ENV["TERRAFORM_RUNNER_URL"] = "https://1.2.3.4:7000"

        create_stub = stub_request(:post, "https://1.2.3.4:7000/api/stack/create")
                      .with(:body => hash_including({:parameters => []}))
                      .to_return(
                        :status => 200,
                        :body   => @hello_world_create_response.to_json
                      )

        retrieve_stub = stub_request(:post, "https://1.2.3.4:7000/api/stack/retrieve")
                        .with(:body => hash_including({:stack_id => @hello_world_retrieve_response['stack_id']}))
                        .to_return(
                          :status => 200,
                          :body   => @hello_world_create_response.to_json
                        )
      end

      let(:input_vars) { {} }

      it "start running hello-world terraform template" do
        async_response = Terraform::Runner.run_async(input_vars, File.join(__dir__, "runner/data/hello-world"))
        expect(create_stub).to(have_been_requested.times(1))

        response = async_response.response
        expect(retrieve_stub).to(have_been_requested.times(1))

        expect(response.status).to(eq('IN_PROGRESS'), "terraform-runner failed with:\n#{response.status}")
        expect(response.stack_id).to(eq(@hello_world_create_response['stack_id']))
        expect(response.action).to(eq('CREATE'))
        expect(response.stack_name).to(eq(@hello_world_create_response['stack_name']))
        expect(response.message).to(be_nil)
        expect(response.details).to(be_nil)

      end
    end

    describe 'ResponseAsync' do
      retrieve_stub = nil

      before do
        ENV["TERRAFORM_RUNNER_URL"] = "https://1.2.3.4:7000"

        retrieve_stub = stub_request(:post, "https://1.2.3.4:7000/api/stack/retrieve")
                        .with(:body => hash_including({:stack_id => @hello_world_retrieve_response['stack_id']}))
                        .to_return(
                          :status => 200,
                          :body   => @hello_world_retrieve_response.to_json
                        )
      end

      it "retrieve hello-world completed result" do
        async_response = Terraform::Runner::ResponseAsync.new(@hello_world_create_response['stack_id'])
        response = async_response.response

        expect(response.status).to(eq('SUCCESS'), "terraform-runner failed with:\n#{response.status}")
        expect(response.message).to(include('greeting = "Hello World"'))
        expect(response.stack_id).to(eq(@hello_world_retrieve_response['stack_id']))
        expect(response.action).to(eq('CREATE'))
        expect(response.stack_name).to(eq(@hello_world_retrieve_response['stack_name']))
        expect(response.details.keys).to(eq(%w[resources outputs]))

        expect(retrieve_stub).to(have_been_requested.times(1))
      end
    end

    describe 'Stop running .run_async template job' do
      create_stub = nil
      retrieve_stub = nil
      cancel_stub = nil

      before do
        ENV["TERRAFORM_RUNNER_URL"] = "https://1.2.3.4:7000"

        create_stub = stub_request(:post, "https://1.2.3.4:7000/api/stack/create")
                      .with(:body => hash_including({:parameters => []}))
                      .to_return(
                        :status => 200,
                        :body   => @hello_world_create_response.to_json
                      )

        cancel_response = @hello_world_create_response.clone
        cancel_response[:status] = 'CANCELLED'

        retrieve_stub = stub_request(:post, "https://1.2.3.4:7000/api/stack/retrieve")
                        .with(:body => hash_including({:stack_id => @hello_world_retrieve_response['stack_id']}))
                        .to_return(
                          :status => 200,
                          :body   => @hello_world_create_response.to_json
                        )
                        .times(2)
                        .then
                        .to_return(
                          :status => 200,
                          :body   => cancel_response.to_json
                        )
        cancel_stub = stub_request(:post, "https://1.2.3.4:7000/api/stack/cancel")
                      .with(:body => hash_including({:stack_id => @hello_world_retrieve_response['stack_id']}))
                      .to_return(
                        :status => 200,
                        :body   => cancel_response.to_json
                      )
      end

      let(:input_vars) { {} }

      it "start running, then stop the before it completes" do
        async_response = Terraform::Runner.run_async(input_vars, File.join(__dir__, "runner/data/hello-world"))
        expect(create_stub).to(have_been_requested.times(1))
        expect(retrieve_stub).to(have_been_requested.times(0))

        response = async_response.response
        expect(retrieve_stub).to(have_been_requested.times(1))

        expect(response.status).to(eq('IN_PROGRESS'), "terraform-runner failed with:\n#{response.status}")
        expect(response.stack_id).to(eq(@hello_world_create_response['stack_id']))
        expect(response.action).to(eq('CREATE'))
        expect(response.stack_name).to(eq(@hello_world_create_response['stack_name']))
        expect(response.message).to(be_nil)
        expect(response.details).to(be_nil)

        # Stop the job terraform-runneer
        async_response.stop
        expect(cancel_stub).to(have_been_requested.times(1))
        expect(retrieve_stub).to(have_been_requested.times(2))

        # fetch latest response
        response = async_response.response
        expect(retrieve_stub).to(have_been_requested.times(3))
        expect(response.status).to(eq('CANCELLED'), "terraform-runner failed with:\n#{response.status}")

        # fetch latest response again, no more api calls
        response = async_response.response
        expect(retrieve_stub).to(have_been_requested.times(3))
        expect(response.status).to(eq('CANCELLED'), "terraform-runner failed with:\n#{response.status}")
      end
    end
  end
end
