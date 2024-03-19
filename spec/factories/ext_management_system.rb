FactoryBot.define do
  # Leaf classes for automation_manager
  factory :embedded_automation_manager_terraform,
          :aliases => ["manageiq/providers/embedded_terraform/automation_manager"],
          :class   => "ManageIQ::Providers::EmbeddedTerraform::AutomationManager",
          :parent  => :embedded_automation_manager do
    provider do
      raise "DO NOT USE!  Use :provider_embedded_terraform and reference the automation_manager from that record"
    end
  end
end
