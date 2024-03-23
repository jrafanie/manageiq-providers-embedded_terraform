require 'rest-client'
require 'timeout'
require 'tempfile'
require 'zip'
require 'base64'

module Terraform
  class Runner
    class << self
      def available?
        return @available if defined?(@available)

        response = terraform_runner_client['api/terraformjobs/count'].get
        @available = response.code == 200
      rescue
        @available = false
      end

      # Run a template, initiates terraform-runner job for running a template, via terraform-runner api
      #
      # @param input_vars [Hash] Hash with key/value pairs that will be passed as input variables to the
      #        terraform-runner run
      # @param template_path [String] Path to the template we will want to run
      # @param tags [Hash] Hash with key/values pairs that will be passed as tags to the terraform-runner run
      # @param credentials [Array] List of Authentication object ids to provide to the terraform run
      # @param env_vars [Hash] Hash with key/value pairs that will be passed as environment variables to the
      #        terraform-runner run
      # @return [Terraform::Runner::ResponseAsync] Response object of terraform-runner create action
      def run_async(input_vars, template_path, tags: nil, credentials: [], env_vars: {})
        _log.info("In run_aysnc with #{template_path}")
        response = create_stack_job(
          template_path,
          :input_vars  => input_vars,
          :tags        => tags,
          :credentials => credentials,
          :env_vars    => env_vars
        )
        Terraform::Runner::ResponseAsync.new(response.stack_id)
      end

      # Stop running terraform-runner job by stack_id
      #
      # @param stack_id [String] stack_id from the terraforn-runner job
      #
      # @return [Terraform::Runner::Response] Response object with result of terraform run
      def stop_async(stack_id)
        cancel_stack_job(stack_id)
      end

      # Runs a template, waits until it terraform-runner job completes, via terraform-runner api
      #
      # @param input_vars [Hash] Hash with key/value pairs that will be passed as input variables to the
      #        terraform-runner run
      # @param template_path [String] Path to the template we will want to run
      # @param tags [Hash] Hash with key/values pairs that will be passed as tags to the terraform-runner run
      # @param credentials [Array] List of Authentication object ids to provide to the terraform run
      # @param env_vars [Hash] Hash with key/value pairs that will be passed as environment variables to the
      #        terraform-runner run
      # @return [Terraform::Runner::Response] Response object with final result of terraform run
      def run(input_vars, template_path, tags: nil, credentials: [], env_vars: {})
        _log.info("Run template: #{template_path}")
        create_stack_job_and_wait_until_completes(
          template_path,
          :input_vars  => input_vars,
          :tags        => tags,
          :credentials => credentials,
          :env_vars    => env_vars
        )
      end

      # Fetch terraform-runner job result/status by stack_id
      #
      # @param stack_id [String] stack_id from the terraforn-runner job
      #
      # @return [Terraform::Runner::Response] Response object with result of terraform run
      def fetch_result_by_stack_id(stack_id)
        retrieve_stack_job(stack_id)
      end

      # =================================================
      # TerraformRunner Stack-API interaction methods
      # =================================================
      private

      def server_url
        ENV['TERRAFORM_RUNNER_URL'] || 'https://localhost:27000'
      end

      def server_token
        # TODO: fix hardcoded token
        ENV['TERRAFORM_RUNNER_TOKEN'] || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IlNodWJoYW5naSBTaW5naCIsImlhdCI6MTcwNjAwMDk0M30.46mL8RRxfHI4yveZ2wTsHyF7s2BAiU84aruHBoz2JRQ'
      end

      def stack_job_interval_in_secs
        ENV['TERRAFORM_RUNNER_STACK_JOB_CHECK_INTERVAL'].to_i
      rescue
        10
      end

      def stack_job_max_time_in_secs
        ENV['TERRAFORM_RUNNER_STACK_JOB_MAX_TIME'].to_i
      rescue
        120
      end

      # Create to paramaters as used by terraform-runner api
      #
      # @param vars [Hash] Hash with key/value pairs that will be passed as input variables to the
      #        terraform-runner run
      # @return [Array] Array of {:name,:value}
      def convert_to_cam_parameters(vars)
        parameters = []
        vars.each do |key, value|
          parameters.push(
            {
              :name  => key,
              :value => value
            }
          )
        end
      end

      # create http client for terraform-runner rest-api
      def terraform_runner_client
        # TODO: verify ssl
        verify_ssl = false

        RestClient::Resource.new(
          server_url,
          :headers    => {:authorization => "Bearer #{server_token}"},
          :verify_ssl => verify_ssl
        )
      end

      def stack_tenant_id
        # TODO: fix hardcoded tenant_id
        'c158d710-d91c-11ed-9fee-d93323035b4e'
      end

      # Create TerraformRunner Stack Job
      def create_stack_job(
        template_path,
        input_vars: [],
        tags: nil,
        credentials: [],
        env_vars: {},
        name: "stack-#{rand(36**8).to_s(36)}"
      )
        _log.info("create_stack_job for #{template_path}")
        tenant_id = stack_tenant_id

        # Temp Zip File
        # zip_file_path = Tempfile.new(%w/tmp .zip/).path
        zip_file_path = Tempfile.new(%w[tmp .zip]).path
        create_zip_file_from_directory(zip_file_path, template_path)
        zip_file_hash = Base64.encode64(File.binread(zip_file_path))

        # TODO: use tags,env_vars
        payload = JSON.generate(
          {
            :cloud_providers => credentials,
            :name            => name,
            :tenantId        => tenant_id,
            :templateZipFile => zip_file_hash,
            :parameters      => convert_to_cam_parameters(input_vars)
          }
        )
        # _log.debug("Payload:>\n, #{payload}")
        http_response = terraform_runner_client['api/stack/create'].post(
          payload, :content_type => 'application/json'
        )
        _log.info("==== http_response.body: \n #{http_response.body}")
        Terraform::Runner::Response.parsed_response(http_response)
      ensure
        # cleanup temp zip file
        FileUtils.rm_rf(zip_file_path) if zip_file_path
        _log.info("Deleted #{zip_file_path}")
      end

      # Retrieve TerraformRunner Stack Job details
      def retrieve_stack_job(stack_id)
        payload = JSON.generate(
          {
            :stack_id => stack_id
          }
        )
        http_response = terraform_runner_client['api/stack/retrieve'].post(
          payload, :content_type => 'application/json'
        )
        _log.info("==== Retrieve Stack Response: \n #{http_response.body}")
        Terraform::Runner::Response.parsed_response(http_response)
      end

      # Cancel/Stop running TerraformRunner Stack Job
      def cancel_stack_job(stack_id)
        payload = JSON.generate(
          {
            :stack_id => stack_id
          }
        )
        http_response = terraform_runner_client['api/stack/cancel'].post(
          payload, :content_type => 'application/json'
        )
        _log.info("==== Cancel Stack Response: \n #{http_response.body}")
        Terraform::Runner::Response.parsed_response(http_response)
      end

      # Wait for TerraformRunner Stack Job to complete
      def wait_until_completes(stack_id)
        interval_in_secs = stack_job_interval_in_secs
        max_time_in_secs = stack_job_max_time_in_secs

        response = nil
        Timeout.timeout(max_time_in_secs) do
          _log.info("Starting wait for terraform-runner/stack/#{stack_id} completes ...")
          i = 0
          loop do
            _log.info(i)
            i += 1

            response = retrieve_stack_job(stack_id)

            _log.info("status: #{response.status}")

            case response.status
            when "SUCCESS"
              _log.info("Successful!")
              break

            when "FAILED"
              _log.info("Failed!!")
              _log.info(response.error_message)
              break

            when nil
              _log.info("No status, must have failed, check response ...")
              _log.info(response.message)
              break
            end
            _log.info("============\n #{response.message} \n============")

            # sleep interval
            _log.info("Sleep for #{interval_in_secs} secs")
            sleep interval_in_secs

            break unless i < 20
          end
          _log.info("loop ends: ran #{i} times")
        end
        response
      end

      # Create TerraformRunner Stack Job, wait until completes
      def create_stack_job_and_wait_until_completes(
        template_path,
        input_vars: [],
        tags: nil,
        credentials: [],
        env_vars: {},
        name: "stack-#{rand(36**8).to_s(36)}"
      )
        _log.info("create_stack_job_and_wait_until_completes for #{template_path}")
        response = create_stack_job(
          template_path,
          :input_vars  => input_vars,
          :tags        => tags,
          :credentials => credentials,
          :env_vars    => env_vars,
          :name        => name
        )
        wait_until_completes(response.stack_id)
      end

      # create zip from directory
      def create_zip_file_from_directory(zip_file_path, template_path)
        dir_path = template_path # directory to be zipped
        dir_path = path[0...-1] if dir_path.end_with?('/')

        _log.info("Create #{zip_file_path}")
        Zip::File.open(zip_file_path, Zip::File::CREATE) do |zipfile|
          Dir.chdir(dir_path)
          Dir.glob("**/*").reject { |fn| File.directory?(fn) }.each do |file|
            _log.info("Adding #{file}")
            zipfile.add(file.sub("#{dir_path}/", ''), file)
          end
        end

        zip_file_path
      end
    end
  end
end
