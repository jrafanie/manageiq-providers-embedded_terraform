module Terraform
  class Runner
    class ResponseAsync
      include Vmdb::Logging

      # Response object designed for holding full response from terraform-runner stack job
      #
      # @param stack_id [String] terraform-runner stack job - stack_id
      def initialize(stack_id)
        @stack_id = stack_id
      end

      # @return [Boolean] true if the terraform stack job is still running, false when it's finished
      def running?
        return false if @response && completed?(@response.status)

        # re-fetch response
        refresh_response

        !completed?(@response.status)
      end

      # Stops the running Terraform job
      def stop
        raise "No job running to stop" if !running?

        Terraform::Runner.stop_async(@stack_id)
      end

      # Re-Fetch async job's response
      def refresh_response
        @response = Terraform::Runner.fetch_result_by_stack_id(@stack_id)

        @response
      end

      # # @return [Terraform::Runner::Response, NilClass] Response object with all details about the Terraform run, or nil
      # #         if the Terraform is still running
      # def response
      #   return if running?
      #
      #   @response
      # end

      # @return [Terraform::Runner::Response] Response object with all details about the Terraform run, or nil
      #         if the Terraform is still running
      def response
        if running?
          _log.info("terraform-runner job [#{@stack_id}] is still running ...")
        end

        @response
      end

      # Dumps the Terraform::Runner::ResponseAsync into the hash
      #
      # @return [Hash] Dumped Terraform::Runner::ResponseAsync object
      def dump
        {
          :stack_id => @stack_id
        }
      end

      # Creates the Terraform::Runner::ResponseAsync object from hash data
      #
      # @param hash [Hash] Dumped Terraform::Runner::ResponseAsync object
      #
      # @return [Terraform::Runner::ResponseAsync] Terraform::Runner::ResponseAsync Object created from hash data
      def self.load(hash)
        # Dump dumps a hash and load accepts a hash, so we must expand the hash to kwargs as new expects kwargs
        new(**hash)
      end

      private

      def completed?(status)
        # IF NOT SUCCESS,FAILED,CANCELLED
        if status
          return (
            status.start_with?("SUCCESS", "FAILED") ||
            # @response.status == "ERROR" ||
            status == "CANCELLED"
          )
        end

        false
      end
    end
  end
end
