module ManageIQ::Providers::EmbeddedTerraform::Provider::DefaultTerraformObjects
  extend ActiveSupport::Concern

  TERRAFORM_OBJECT_SOURCE = "MIQ_TERRAFORM".freeze

  included do
    has_many :default_terraform_objects, -> { where(:source => TERRAFORM_OBJECT_SOURCE) }, :as => :resource, :dependent => :destroy, :class_name => "CustomAttribute"
  end

  def default_organization
    get_default_terraform_object("organization")
  end

  def default_organization=(org)
    set_default_terraform_object("organization", org)
  end

  private

  def get_default_terraform_object(name)
    default_terraform_objects.find_by(:name => name).try(:value).try(:to_i)
  end

  def set_default_terraform_object(name, value)
    default_terraform_objects.find_or_initialize_by(:name => name).update(:value => value)
  end
end
