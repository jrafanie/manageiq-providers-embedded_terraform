class ManageIQ::Providers::EmbeddedTerraform::AutomationManager::Template < ManageIQ::Providers::EmbeddedAutomationManager::ConfigurationScriptPayload
  has_many :jobs, :class_name => 'OrchestrationStack', :foreign_key => :configuration_script_base_id

  def run(vars = {}, _userid = nil)
  end
end
