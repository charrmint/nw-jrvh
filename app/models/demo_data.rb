# Placeholder applications for the front end until applications are stored.
# Delete once real application models exist.
module DemoData
  APPLICATIONS = [
    { id: "little-steps", daycare: "Little Steps Daycare", child: "Sample child", care: "Full-time · Mon–Fri", status: "Missing information", updated: "Today",
      needs: [ "Immunization record", "Emergency contact confirmation" ], timeline_current: 1 },
    { id: "bright-start", daycare: "Bright Start Childcare", child: "Sample child", care: "Part-time · Tue–Thu", status: "Ready to review", updated: "Yesterday",
      needs: [], timeline_current: 2 },
    { id: "cedar-grove", daycare: "Cedar Grove Early Learning", child: "Sample child", care: "Full-time · Mon–Fri", status: "In review", updated: "Nov 5",
      needs: [], timeline_current: 4 }
  ].freeze

  BEFORE_SUBMISSION = [ "Profile complete", "Missing information", "Ready to submit" ].freeze
  AFTER_SUBMISSION  = [ "Submitted", "Information requested", "In review", "Decision" ].freeze

  def self.application(id) = APPLICATIONS.find { |a| a[:id] == id }
end
