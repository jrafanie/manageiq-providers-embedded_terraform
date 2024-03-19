class ManageIQ::Providers::EmbeddedTerraform::AutomationManager::ConfigurationScriptSource < ManageIQ::Providers::EmbeddedAutomationManager::ConfigurationScriptSource
  FRIENDLY_NAME = "Embedded Terraform Repository".freeze

  def self.display_name(number = 1)
    n_('Repository (Embedded Terraform)', 'Repositories (Embedded Terraform)', number)
  end

  def sync
    update!(:status => "running")

    transaction do
      current = configuration_script_payloads.index_by(&:name)

      templates = find_templates_in_git_repo
      templates.each do |template_path, value|
        _log.info("Template: #{template_path} => #{value.to_json}")

        found = current.delete(template_path) || self.class.module_parent::ConfigurationScriptPayload.new(:configuration_script_source_id => id)

        attrs = {
          :name         => template_path,
          :manager_id   => manager_id,
          :payload      => value.to_json,
          :payload_type => 'json'
        }

        found.update!(attrs)
      end

      current.each_value(&:destroy)
      configuration_script_payloads.reload
    end

    update!(:status => "successful", :last_updated_on => Time.zone.now, :last_update_error => nil)
  rescue => error
    update!(:status => "error", :last_updated_on => Time.zone.now, :last_update_error => error)
    raise error
  end

  # Return Template name, using relative_path's basename prefix,
  #   and suffix with git-repo url details
  #     'basename(branch_name):hostname/path/relative_path_parent)'
  # eg.
  #   https://github.ibm.com/manoj-puthran/sample-scripts/tree/v2.0/terraform/templates/hello-world
  #       is converted as
  #   "hello-world(v2.0):github.ibm.com/manoj-puthran/sample-scripts/terraform/templates"
  def self.template_name_from_git_repo_url(git_repo_url, branch_name, relative_path)
    temp_url = git_repo_url
    # URI library cannot handle git urls, so just convert it to a standard url.
    temp_url = temp_url.sub(':', '/').sub('git@', 'https://') if temp_url.start_with?('git@')
    temp_uri = URI.parse(temp_url)
    hostname = temp_uri.hostname
    path = temp_uri.path
    path = path[0...-4] if path.end_with?('.git')
    path = path[0...-5] if path.end_with?('.git/')
    # if template dir is root, then use repo name as basename
    if relative_path == '.'
      basename = File.basename(path)
      parent_path = ''
    else
      basename = File.basename(relative_path)
      parent_path = File.dirname(relative_path)
    end
    "#{basename}(#{branch_name}):#{hostname}#{path}/#{parent_path}"
  end

  private

  # Find Terraform Templates(dir) in the git repo.
  # Iterate through git repo worktree, and collate all terraform template dir's (dirs with .tf or .tf.json files).
  #
  # Returns [Hash] of template directories and files within it.
  def find_templates_in_git_repo
    template_dirs = {}

    # checkout files to temp dir, we need for parsing input/output vars
    git_checkout_tempdir = Dir.mktmpdir("terraform-git")
    checkout_git_repository(git_checkout_tempdir)

    # traverse through files in git-worktree
    git_repository.with_worktree do |worktree|
      worktree.ref = scm_branch

      # Find all dir's with .tf/.tf.json files
      worktree.blob_list.each do |filepath|
        next unless filepath.end_with?(".tf", ".tf.json")

        parent_dir = File.dirname(filepath)
        name = ManageIQ::Providers::EmbeddedTerraform::AutomationManager::ConfigurationScriptSource.template_name_from_git_repo_url(
          git_repository.url, scm_branch, parent_dir
        )

        next if template_dirs.key?(name)

        full_path = File.join(git_checkout_tempdir, parent_dir)
        _log.debug("Local full path : #{full_path}")
        files = Dir.children(full_path)

        # TODO: add parsing for input/output vars
        input_vars = nil
        output_vars = nil

        template_dirs[name] = {
          :relative_path => parent_dir,
          :files         => files,
          :input_vars    => input_vars,
          :output_vars   => output_vars
        }
        _log.debug("=== Add Template:#{name}")
      end
    end

    template_dirs
  ensure
    # cleanup temp git directory
    FileUtils.rm_rf(git_checkout_tempdir) if git_checkout_tempdir
  end
end
