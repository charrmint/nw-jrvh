# Placeholder content used by the front end until the backend stores children,
# profiles and applications. Mirrors the Figma frames. Delete once real models exist.
module DemoData
  Child = Struct.new(:id, :first_name, :last_name, :dob, :complete, keyword_init: true) do
    def full_name = "#{first_name} #{last_name}"
  end

  CHILDREN = [
    Child.new(id: "maya", first_name: "Maya", last_name: "Chen", dob: "May 4, 2024", complete: 78)
  ].freeze

  APPLICATIONS = [
    { id: "little-steps", daycare: "Little Steps Daycare", child: "Maya Chen", care: "Full-time · Mon–Fri", status: "Missing information", updated: "Today",
      needs: [ "Immunization record", "Emergency contact confirmation" ], timeline_current: 1 },
    { id: "bright-start", daycare: "Bright Start Childcare", child: "Maya Chen", care: "Part-time · Tue–Thu", status: "Ready to review", updated: "Yesterday",
      needs: [], timeline_current: 2 },
    { id: "cedar-grove", daycare: "Cedar Grove Early Learning", child: "Maya Chen", care: "Full-time · Mon–Fri", status: "In review", updated: "Nov 5",
      needs: [], timeline_current: 4 }
  ].freeze

  BEFORE_SUBMISSION = [ "Profile complete", "Missing information", "Ready to submit" ].freeze
  AFTER_SUBMISSION  = [ "Submitted", "Information requested", "In review", "Decision" ].freeze

  OVERVIEW = {
    "Basic information" => [ [ "First name", "Maya" ], [ "Last name", "Chen" ], [ "Date of birth", "May 4, 2024" ], [ "Pronouns", nil ] ],
    "Care preferences"  => [ [ "Care type", "Full-time daycare" ], [ "Start date", "September 2027" ], [ "Schedule", "Monday–Friday" ], [ "Hours", "8:00 AM–5:00 PM" ] ],
    "Health and safety" => [ [ "Allergies", "None" ], [ "Medication", "None" ], [ "Immunization", "Record uploaded" ], [ "Doctor", nil ] ],
    "Food and feeding"  => [ [ "Dietary needs", "Vegetarian" ], [ "Food sensitivities", "None" ], [ "Feeding support", "None" ], [ "Favourite foods", "Berries and pasta" ] ]
  }.freeze

  OVERVIEW_EDIT = {
    "Basic information" => "identity", "Care preferences" => "care",
    "Health and safety" => "health_contacts", "Food and feeding" => "feeding"
  }.freeze

  def self.child(id) = CHILDREN.find { |c| c.id == id } || CHILDREN.first
  def self.application(id) = APPLICATIONS.find { |a| a[:id] == id }
end
