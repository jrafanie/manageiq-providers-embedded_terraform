module Terraform
  class Runner
    class ResponseAsync
      include Vmdb::Logging

      attr_reader :response, :debug

      # Response object designed for holding full response from terraform-runner
      #
      # @param response [Object] Terraform::Runner::Response object
      # @param debug [Boolean] whether or not to delete base_dir after run (for debugging)
      def initialize(response, debug: false)
        @response = response
        @debug    = debug
      end

      # @return [Boolean] true if the terraform job is still running, false when it's finished
      def running?
        response.status == "IN_PROGRESS"
      end

      # Stops the running Terraform job
      def stop
        raise NotImplementedError, "Not yet impleted"
      end

      # Dumps the Terraform::Runner::ResponseAsync into the hash
      #
      # @return [Hash] Dumped Terraform::Runner::ResponseAsync object
      def dump
        {
          :response => response,
          :debug    => debug
        }
      end

      # Creates the Terraform::Runner::ResponseAsync object from hash data
      #
      # @param hash [Hash] Dumped Ansible::Runner::ResponseAsync object
      # @return [Terraform::Runner::ResponseAsync] Ansible::Runner::ResponseAsync Object created from hash data
      def self.load(hash)
        # Dump dumps a hash and load accepts a hash, so we must expand the hash to kwargs as new expects kwargs
        new(**hash)
      end
    end
  end
end
