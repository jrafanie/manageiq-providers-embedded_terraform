require 'json'

module Terraform
  class Runner
    class Response
      include Vmdb::Logging

      attr_reader :stack_id, :stack_name, :status, :action, :message, :error_message,
                  :details, :created_at, :stack_job_start_time, :stack_job_end_time

      # @return [String] Extracted attributes from the JSON response body object
      def self.parsed_response(http_response)
        data = JSON.parse(http_response.body)
        _log.debug("data : #{data}")
        Terraform::Runner::Response.new(
          :stack_id             => data['stack_id'],
          :stack_name           => data['stack_name'],
          :status               => data['status'],
          :action               => data['action'],
          :message              => data['message'],
          :error_message        => data['error_message'],
          :details              => data['details'],
          :created_at           => data['created_at'],
          :stack_job_start_time => data['stack_job_start_time'],
          :stack_job_end_time   => data['stack_job_end_time']
        )
      end

      # Response object designed for holding full response from terraform-runner
      #
      # @param stack_id [String] terraform-runner stack instance id
      # @param stack_name [String] name of the stack instance
      # @param status [String] IN_PROGRESS/SUCCESS/FAILED
      # @param action [String] action performed CREATE,DESTROY,etc
      # @param message [String] Stdout from terraform-runner stack instance run
      # @param error_message [String] Stderr from terraform-runner run instance run
      # @param debug [Boolean] whether or not to delete base_dir after run (for debugging)
      # @param details [Hash]
      # @param created_at [String]
      # @param stack_job_start_time [String]
      # @param stack_job_end_time [String]
      def initialize(stack_id:, stack_name: nil, status: nil, action: nil, message: nil, error_message: nil, details: nil, created_at: nil, stack_job_start_time: nil, stack_job_end_time: nil)
        @stack_id      = stack_id
        @stack_name    = stack_name
        @status        = status
        @action        = action
        @message       = message
        @error_message = error_message
        @details       = details
        @created_at    = created_at
        @stack_job_start_time = stack_job_start_time
        @stack_job_end_time   = stack_job_end_time
      end
    end
  end
end
