FactoryBot.define do
  factory :provider_embedded_terraform, :class => "ManageIQ::Providers::EmbeddedTerraform::Provider", :parent => :provider
end
