require "test_helper"

class Automation::FieldInventoryTest < ActiveSupport::TestCase
  test "fingerprint ignores hash key order but preserves choice order" do
    first = Automation::FieldInventory.new(
      step: "child",
      fields: [ { key: "support", choices: %w[Yes No], required: true } ]
    )
    reordered = Automation::FieldInventory.new(
      fields: [ { required: true, choices: %w[Yes No], key: "support" } ],
      step: "child"
    )
    changed = Automation::FieldInventory.new(
      step: "child",
      fields: [ { key: "support", choices: %w[No Yes], required: true } ]
    )

    assert_equal first.fingerprint, reordered.fingerprint
    refute_equal first.fingerprint, changed.fingerprint
  end
end
