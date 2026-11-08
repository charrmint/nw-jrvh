require "test_helper"

class Integrations::MappingValidatorTest < ActiveSupport::TestCase
  test "keeps only observed mappings and allowed live defaults" do
    inventory = {
      fields: [
        { key: "parent.first_name", type: "text" },
        { key: "priority.ymca_employee", type: "select", choices: %w[Yes No] },
        { key: "parent.marketing_sms", type: "checkbox" }
      ]
    }
    proposal = {
      mappings: {
        "parent.first_name" => "parent.first_name",
        "missing.live.field" => "parent.last_name",
        "priority.ymca_employee" => "unknown.catalog.key"
      },
      defaults: {
        "priority.ymca_employee" => "No",
        "parent.marketing_sms" => "No",
        "missing.live.field" => "No"
      }
    }

    result = Integrations::MappingValidator.new(
      inventory: inventory,
      canonical_catalog: %w[parent.first_name parent.last_name],
      allowed_default_policy: {
        provider_specific_priority: "No",
        marketing_sms: "No"
      }
    ).call(proposal)

    assert_equal({ "parent.first_name" => "parent.first_name" }, result.mapping)
    assert_equal(
      { "priority.ymca_employee" => "No", "parent.marketing_sms" => "No" },
      result.defaults
    )
    assert_equal 3, result.warnings.size
  end

  test "never accepts Yes as an eligibility-like default" do
    result = Integrations::MappingValidator.new(
      inventory: { fields: [ { key: "eligibility.catchment", type: "select", choices: %w[Yes No] } ] },
      canonical_catalog: %w[school.catchment],
      allowed_default_policy: { provider_specific_priority: "No" }
    ).call(defaults: { "eligibility.catchment" => "Yes" })

    assert_empty result.defaults
  end

  test "materializes agreed No defaults without trusting the model proposal" do
    result = Integrations::MappingValidator.new(
      inventory: {
        fields: [
          { key: "priority.ymca_employee", type: "select", choices: %w[Yes No] },
          { key: "parent.marketing_sms", type: "checkbox" }
        ]
      },
      canonical_catalog: %w[parent.application_sms_consent priority.affiliations],
      allowed_default_policy: {
        provider_specific_priority: "No",
        marketing_sms: "No"
      }
    ).call(
      mappings: {
        "priority.ymca_employee" => "priority.affiliations",
        "parent.marketing_sms" => "parent.application_sms_consent"
      }
    )

    assert_empty result.mapping
    assert_equal(
      { "priority.ymca_employee" => "No", "parent.marketing_sms" => "No" },
      result.defaults
    )
    assert_equal 2, result.warnings.size
  end
end
