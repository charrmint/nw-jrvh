# Front-end definition of the reusable child profile (the OneKare question map).
# Nothing here is stored yet: the forms render from this structure, and the backend
# can later map each field id to a column / normalized field.
module ProfileSchema
  Field   = Struct.new(:id, :label, :type, :options, :show_if, :sensitive, :hint, keyword_init: true)
  Section = Struct.new(:key, :title, :tab, :intro, :repeatable, :fields, keyword_init: true)

  TABS = {
    "overview"    => "Overview",
    "health"      => "Health",
    "food"        => "Food",
    "sleep"       => "Sleep",
    "development" => "Development",
    "more"        => "More"
  }.freeze

  DAYS      = %w[Monday Tuesday Wednesday Thursday Friday Saturday Sunday].freeze
  SCHEDULES = [ "Full-time", "Part-time", "Drop-in", "Before-school", "After-school" ].freeze
  PROGRAMS  = [ "Infant", "Toddler", "Preschool", "School age", "Other" ].freeze
  SUPPORT_AREAS = %w[Speech Hearing Vision Motor Learning Social Emotional Sensory Other].freeze

  def self.f(id, label, type = :text, options: nil, show_if: nil, sensitive: false, hint: nil)
    Field.new(id: id, label: label, type: type, options: options, show_if: show_if, sensitive: sensitive, hint: hint)
  end

  def self.s(key, title, tab, intro = nil, repeatable: false, &block)
    @sections ||= []
    @sections << Section.new(key: key, title: title, tab: tab, intro: intro, repeatable: repeatable, fields: block.call)
  end

  s("identity", "Child identity", "overview", "The basics daycares ask for on every application.") do [
    f("child.legal_first_name", "What is your child’s legal first name?"),
    f("child.legal_middle_name", "What is your child’s legal middle name?", hint: "Optional"),
    f("child.legal_last_name", "What is your child’s legal last name?"),
    f("child.preferred_name", "What name does your child prefer to use?", hint: "Optional"),
    f("child.date_of_birth", "What is your child’s date of birth?", :date),
    f("child.expected_due_date", "What is the expected due date?", :date, hint: "Only if your child has not been born yet."),
    f("child.sex_for_licensing", "What sex is recorded for licensing purposes?", :single_select, options: [ "Female", "Male", "Another designation", "Prefer not to say" ], sensitive: true, hint: "B.C. licensed providers are required to record this at enrolment."),
    f("child.gender_identity", "How does your child identify their gender?", sensitive: true, hint: "Optional"),
    f("child.pronouns", "What pronouns should caregivers use?", :single_select, options: [ "she/her", "he/him", "they/them", "Other" ], hint: "Optional"),
    f("child.home_address", "What is your child’s home address?", :address),
    f("child.photo", "Upload a current photo of your child.", :document, sensitive: true, hint: "Used privately for emergency identification only."),
    f("child.identifying_features", "Are there identifying features staff should know for an emergency?", :long_text, sensitive: true, hint: "Optional"),
    f("child.height", "What is your child’s approximate height?"),
    f("child.weight", "What is your child’s approximate weight?"),
    f("child.hair_colour", "What is your child’s hair colour?"),
    f("child.eye_colour", "What is your child’s eye colour?"),
    f("child.proof_of_age", "Upload proof of age or a birth certificate.", :document, sensitive: true, hint: "Only needed at the offer stage by some providers.")
  ] end

  s("care", "Care request and schedule", "overview", "What kind of care you need and when.") do [
    f("care.requested_centres", "Which daycare locations are you applying to?", :list, hint: "One per line. You can also pick these when you start an application."),
    f("care.program_type", "What type of care are you looking for?", :multi_select, options: PROGRAMS),
    f("care.desired_start_date", "When would you like care to begin?", :date),
    f("care.latest_start_date", "What is the latest acceptable start date?", :date),
    f("care.start_date_flexible", "Is your start date flexible?", :boolean),
    f("care.schedule_type", "Which kind of care schedule do you need?", :multi_select, options: SCHEDULES),
    f("care.days_needed", "Which days do you need care?", :multi_select, options: DAYS),
    f("care.dropoff_time", "What is the required drop-off time?", :time),
    f("care.pickup_time", "What is the required pickup time?", :time),
    f("care.schedule_flexible", "Is your weekly schedule flexible?", :boolean),
    f("care.alternate_schedule", "What alternate schedule could work?", :long_text, show_if: "care.schedule_flexible"),
    f("care.expected_duration", "How long do you expect to need care?"),
    f("care.transportation_needed", "Does your child need transportation to or from school?", :boolean, hint: "School-age children only."),
    f("care.school_pickup_location", "Where should your child be picked up from school?", show_if: "care.transportation_needed"),
    f("care.school_dismissal_time", "What time is school dismissal?", :time, show_if: "care.transportation_needed")
  ] end

  s("school", "School information", "overview", "For school-age care only. Skip this if your child isn’t in school yet.") do [
    f("school.name", "What school does your child attend?"),
    f("school.grade", "What grade is your child in?"),
    f("school.teacher_name", "Who is your child’s teacher?"),
    f("school.phone", "What is the school’s phone number?", :phone),
    f("school.catchment", "What school catchment does your child live in?")
  ] end

  s("guardians", "Parents and guardians", "more", "Guardians are saved to your family account and linked to each child.", repeatable: true) do [
    f("legal_first_name", "Legal first name"),
    f("legal_last_name", "Legal last name"),
    f("relationship", "Relationship to the child", :single_select, options: [ "Mother", "Father", "Guardian", "Other" ]),
    f("legal_guardian", "Is this person a legal guardian?", :single_select, options: %w[Yes No], sensitive: true),
    f("custody_status", "Are there custody or access conditions that affect care?", :single_select, options: %w[Yes No], sensitive: true),
    f("address", "Home address", :address),
    f("email", "Email address", :email),
    f("mobile_phone", "Mobile number", :phone),
    f("home_phone", "Home number", :phone),
    f("work_phone", "Work number", :phone),
    f("preferred_contact_method", "How should this guardian be contacted first?", :single_select, options: [ "Phone", "Text", "Email" ]),
    f("preferred_language", "Preferred language for contact"),
    f("employer", "Employer"),
    f("occupation", "Occupation"),
    f("work_address", "Work address", :address),
    f("work_days", "Usual work days", :multi_select, options: DAYS),
    f("work_hours", "Usual work hours"),
    f("identity_document", "Government-issued identification", :document, sensitive: true, hint: "Only requested at the offer stage.")
  ] end

  s("emergency_contacts", "Emergency contacts", "more", "People daycare can call if they can’t reach a parent.", repeatable: true) do [
    f("full_name", "Full name"),
    f("relationship", "Relationship to the child"),
    f("primary_phone", "Primary phone", :phone),
    f("secondary_phone", "Secondary phone", :phone),
    f("work_phone", "Work phone", :phone),
    f("address", "Address", :address),
    f("priority", "Order to be contacted (1 = first)", :integer),
    f("can_pick_up", "Authorized to pick up the child?", :single_select, options: %w[Yes No])
  ] end

  s("authorized_pickups", "Authorized pickup", "more", "Anyone other than a parent who may collect your child.", repeatable: true) do [
    f("full_name", "Legal name"),
    f("relationship", "Relationship to the child"),
    f("phone", "Phone number", :phone),
    f("authorization_type", "Ongoing or one-time authorization?", :single_select, options: [ "Ongoing", "One-time" ])
  ] end

  s("restricted_access", "Restricted access", "more", "Only fill this in if someone is not permitted to access your child.") do [
    f("access.has_restricted_person", "Is anyone prohibited or restricted from accessing the child?", :boolean, sensitive: true),
    f("restricted_person.full_name", "Restricted person’s name", show_if: "access.has_restricted_person", sensitive: true),
    f("restricted_person.relationship", "Their relationship to the child", show_if: "access.has_restricted_person", sensitive: true),
    f("restricted_person.restriction_details", "What restriction must the daycare follow?", :long_text, show_if: "access.has_restricted_person", sensitive: true),
    f("restricted_person.supporting_document", "Custody agreement, court order, or safety document", :document, show_if: "access.has_restricted_person", sensitive: true),
    f("access.safe_release_instructions", "Any special safe-release instructions?", :long_text, show_if: "access.has_restricted_person", sensitive: true)
  ] end

  s("health_contacts", "Doctor and health contacts", "health", "Health numbers are only requested once a daycare offers you a spot.") do [
    f("health.phn", "Personal Health Number (PHN)", sensitive: true, hint: "Never shown in search results."),
    f("health.medical_practitioner_name", "Who is your child’s doctor or medical practitioner?"),
    f("health.medical_practitioner_phone", "Practitioner’s phone number", :phone),
    f("health.clinic_name", "Clinic name"),
    f("health.clinic_address", "Clinic address", :address),
    f("health.dentist_name", "Who is your child’s dentist?"),
    f("health.dentist_phone", "Dentist’s phone number", :phone),
    f("health.preferred_hospital", "Preferred hospital or emergency centre"),
    f("health.has_condition", "Does your child have an illness, chronic condition, disability, or medical concern?", :boolean, sensitive: true),
    f("health.conditions", "Describe each relevant health condition.", :list, show_if: "health.has_condition", sensitive: true, hint: "One per line."),
    f("health.condition_details", "What should caregivers know about this?", :long_text, show_if: "health.has_condition", sensitive: true),
    f("health.vision_or_hearing_concern", "Does your child have a vision or hearing concern?", :boolean),
    f("health.ongoing_medical_care", "Does your child require ongoing medical care?", :boolean),
    f("health.activity_limitations", "Is there anything that may prevent participation in regular activities?", :boolean),
    f("health.emergency_protocol", "Special emergency procedures staff must follow", :long_text, sensitive: true)
  ] end

  s("immunization", "Immunization", "health", "Upload the record once and reuse it on every application.") do [
    f("immunization.status", "What is your child’s immunization status?", :single_select, options: [ "Complete", "Partial", "Not immunized", "Unknown" ]),
    f("immunization.dates", "Enter known immunization dates.", :list, sensitive: true, hint: "One per line, e.g. “MMR – 2025-05-04”."),
    f("immunization.record", "Upload the immunization record.", :document, sensitive: true),
    f("immunization.exemption", "Is there exemption or explanatory documentation?", :boolean),
    f("immunization.exemption_document", "Upload the supporting documentation.", :document, show_if: "immunization.exemption", sensitive: true)
  ] end

  s("allergies", "Allergies and reactions", "health") do [
    f("allergy.has_allergies", "Does your child have any allergies?", :boolean),
    f("allergy.category", "What type of allergy is it?", :single_select, options: %w[Food Environmental Medication Insect Other], show_if: "allergy.has_allergies", sensitive: true),
    f("allergy.allergen", "What is your child allergic to?", show_if: "allergy.has_allergies", sensitive: true),
    f("allergy.reaction", "What reaction occurs?", :long_text, show_if: "allergy.has_allergies", sensitive: true),
    f("allergy.severity", "How severe can the reaction be?", :single_select, options: %w[Mild Moderate Severe], show_if: "allergy.has_allergies", sensitive: true),
    f("allergy.life_threatening", "Is this allergy life-threatening?", :boolean, show_if: "allergy.has_allergies", sensitive: true),
    f("allergy.prevention", "How should exposure be prevented?", :long_text, show_if: "allergy.has_allergies"),
    f("allergy.emergency_response", "What should staff do if exposure occurs?", :long_text, show_if: "allergy.has_allergies"),
    f("allergy.action_plan", "Upload the allergy or anaphylaxis action plan.", :document, show_if: "allergy.has_allergies", sensitive: true),
    f("allergy.rescue_medication", "What rescue medication is required and where should it be stored?", :long_text, show_if: "allergy.has_allergies", sensitive: true)
  ] end

  s("medication", "Medication", "health") do [
    f("medication.uses_regular_medication", "Does your child take regular medication?", :boolean),
    f("medication.name", "Medication name", show_if: "medication.uses_regular_medication"),
    f("medication.reason", "What is the medication for?", show_if: "medication.uses_regular_medication", sensitive: true),
    f("medication.dose", "What dose is required?", show_if: "medication.uses_regular_medication"),
    f("medication.route", "How is it administered?", :single_select, options: %w[Oral Inhaled Topical Injection Other], show_if: "medication.uses_regular_medication"),
    f("medication.schedule", "When should it be administered?", show_if: "medication.uses_regular_medication"),
    f("medication.storage", "How must it be stored?", show_if: "medication.uses_regular_medication"),
    f("medication.expiry_date", "When does it expire?", :date, show_if: "medication.uses_regular_medication"),
    f("medication.prescriber", "Who prescribed it?", show_if: "medication.uses_regular_medication"),
    f("medication.administer_during_care", "Must daycare staff administer it?", :boolean, show_if: "medication.uses_regular_medication"),
    f("medication.self_administer", "Is the child permitted to self-administer it?", :boolean, show_if: "medication.uses_regular_medication"),
    f("medication.authorization", "Do you authorize the provider to administer this medication as instructed?", :consent, show_if: "medication.uses_regular_medication", hint: "Asked again for each provider.")
  ] end

  s("feeding", "Food, diet, and feeding", "food") do [
    f("feeding.dietary_restrictions", "Does your child have dietary restrictions?", :boolean),
    f("feeding.diet_types", "Which dietary requirements apply?", :multi_select, options: [ "Vegetarian", "Vegan", "Halal", "Kosher", "No pork", "Dairy-free", "Gluten-free", "Other" ], show_if: "feeding.dietary_restrictions"),
    f("feeding.therapeutic_diet", "Is there a therapeutic diet prescribed by a professional?", :boolean),
    f("feeding.foods_to_avoid", "Are there foods your child must not eat?", :long_text),
    f("feeding.food_dislikes", "Which foods does your child dislike?", :long_text),
    f("feeding.favourite_foods", "What are your child’s favourite foods?", :long_text),
    f("feeding.special_habits", "Are there special eating habits caregivers should know about?", :long_text),
    f("feeding.difficulties", "Does your child have eating or swallowing difficulties?", :boolean),
    f("feeding.breastfeeding_plan", "Is your child breastfeeding or receiving expressed milk?", :boolean),
    f("feeding.formula_plan", "Does your child receive formula?", :boolean, hint: "Provider will ask for brand, preparation, amount and schedule."),
    f("feeding.cup_or_bottle", "What bottle or cup does your child use?", :multi_select, options: [ "Bottle", "Sippy cup", "Open cup", "Straw cup" ]),
    f("feeding.solid_food_stage", "What is your child’s current solid-food stage?", :single_select, options: [ "Not started", "Purées", "Soft finger foods", "Table foods" ]),
    f("feeding.meal_schedule", "What is your child’s usual meal and snack schedule?", :long_text),
    f("feeding.assistance", "Does your child need help eating or drinking?", :boolean),
    f("feeding.goals", "Are there eating or self-help goals?", :long_text)
  ] end

  s("sleep", "Sleep and rest", "sleep") do [
    f("sleep.naps", "Does your child nap?", :boolean),
    f("sleep.nap_count", "How many naps does your child usually take?", :integer, show_if: "sleep.naps"),
    f("sleep.nap_times", "When does your child usually nap?", show_if: "sleep.naps"),
    f("sleep.nap_duration", "How long does your child usually nap?", show_if: "sleep.naps"),
    f("sleep.bedtime", "Usual bedtime", :time),
    f("sleep.wake_time", "Usual wake time", :time),
    f("sleep.falling_asleep", "What helps your child fall asleep?", :long_text),
    f("sleep.rituals", "Sleep or wake rituals caregivers should follow", :long_text),
    f("sleep.comfort_items", "Blanket, pacifier, toy, lighting, or sound used for sleep", :long_text),
    f("sleep.difficulties", "Are there sleep difficulties caregivers should know about?", :boolean, sensitive: true),
    f("sleep.tiredness_signs", "How can caregivers tell your child is tired?", :long_text),
    f("sleep.waking_mood", "How does your child usually feel when waking?"),
    f("sleep.non_sleeper_rest", "If your child does not sleep, what quiet activity should be offered?", :long_text),
    f("sleep.family_expectations", "What are your expectations for rest time?", :long_text)
  ] end

  s("toileting", "Toileting and diapering", "sleep") do [
    f("toileting.status", "Is your child in diapers, toilet learning, or independently toileting?", :single_select, options: [ "In diapers", "Toilet learning", "Independent" ]),
    f("toileting.diaper_type", "What diaper or pull-up type is used?"),
    f("toileting.change_instructions", "Special diaper-changing instructions", :long_text),
    f("toileting.rash", "Is your child prone to diaper rash?", :boolean),
    f("toileting.approved_products", "Which creams or products may be used?", :long_text, hint: "A separate consent is collected for each provider."),
    f("toileting.equipment", "Potty chair, insert, or regular toilet?", :single_select, options: [ "Potty chair", "Toilet insert", "Regular toilet" ]),
    f("toileting.signals", "How does your child communicate that they need the toilet?", :long_text),
    f("toileting.words_used", "Words your child uses for toileting and body parts", :long_text),
    f("toileting.assistance", "Does your child need reminders, help with clothing, or wiping?", :multi_select, options: [ "Reminders", "Help with clothing", "Help wiping" ]),
    f("toileting.schedule", "Is there a regular toileting schedule?", :long_text),
    f("toileting.accidents", "Are accidents common or linked to certain situations?", :long_text),
    f("toileting.health_concerns", "Constipation, diarrhea, urination, or other relevant concerns", :long_text, sensitive: true),
    f("toileting.goals", "Toileting approach or goals caregivers should follow", :long_text)
  ] end

  s("support", "Development and extra support", "development", "Share only what helps a daycare support your child.") do [
    f("support.needs_extra_support", "Does your child need extra support to participate safely and fully?", :boolean),
    f("support.areas", "Which areas need support?", :multi_select, options: SUPPORT_AREAS, show_if: "support.needs_extra_support"),
    f("support.details", "Describe the support your child needs.", :long_text, show_if: "support.needs_extra_support", sensitive: true),
    f("support.diagnoses", "Are there relevant professional diagnoses?", :long_text, show_if: "support.needs_extra_support", sensitive: true),
    f("support.assessment_status", "Is your child assessed, being assessed, or waiting for testing?", :single_select, options: [ "Assessed", "Being assessed", "Waiting for testing", "Not applicable" ], show_if: "support.needs_extra_support"),
    f("support.assessment_documents", "Upload relevant assessment documents.", :document, show_if: "support.needs_extra_support", sensitive: true),
    f("support.therapies", "Is your child receiving therapy or intervention?", :multi_select, options: [ "Speech therapy", "Occupational therapy", "Physiotherapy", "Behavioural support", "Other" ], show_if: "support.needs_extra_support"),
    f("support.therapy_details", "Describe current therapies or interventions.", :long_text, show_if: "support.needs_extra_support"),
    f("support.agencies", "Which support programs or agencies are involved?", :multi_select, options: [ "Supported Child Development", "Infant Development Program", "BC Centre for Ability", "Health authority", "Other" ], show_if: "support.needs_extra_support"),
    f("support.funding_status", "Is support funding approved, pending, or not requested?", :single_select, options: [ "Approved", "Pending", "Not requested" ], show_if: "support.needs_extra_support"),
    f("support.worker_contact", "Support worker or agency contact", show_if: "support.needs_extra_support"),
    f("support.professional_recommendations", "What actions have professionals recommended?", :long_text, show_if: "support.needs_extra_support"),
    f("support.required_adaptations", "Physical or environmental adaptations required", :long_text, show_if: "support.needs_extra_support"),
    f("support.activity_modifications", "Program or activity modifications required", :long_text, show_if: "support.needs_extra_support"),
    f("support.strengths", "What are your child’s strengths?", :long_text),
    f("support.current_goals", "What goals are you currently working toward?", :long_text),
    f("support.what_helps", "What helps your child participate successfully?", :long_text),
    f("support.care_plan", "Upload the current care plan.", :document, show_if: "support.needs_extra_support", sensitive: true)
  ] end

  s("routine", "Routine and transition into care", "development") do [
    f("routine.typical_day", "Describe your child’s typical weekday routine.", :long_text),
    f("routine.previous_care", "Has your child been cared for outside the home?", :boolean),
    f("routine.previous_provider_name", "Previous provider’s name", show_if: "routine.previous_care"),
    f("routine.previous_provider_dates", "When did your child attend?", show_if: "routine.previous_care"),
    f("routine.previous_provider_phone", "Previous provider’s phone number", :phone, show_if: "routine.previous_care"),
    f("routine.separation_response", "How does your child usually react when separating from family?", :long_text),
    f("routine.new_situations", "How does your child respond to new people, places, or room transitions?", :long_text),
    f("routine.dropoff_support", "What helps during drop-off?", :long_text),
    f("routine.comfort_items", "Comfort items or familiar rituals that help", :long_text),
    f("routine.gradual_entry", "Would a gradual-entry plan or transition visit help?", :boolean)
  ] end

  s("communication", "Communication, behaviour, and social development", "development") do [
    f("communication.home_language", "First or primary language used at home"),
    f("communication.other_languages", "Other languages your child understands or uses", :list, hint: "One per line."),
    f("communication.methods", "How does your child communicate?", :multi_select, options: [ "Speech", "Signs", "AAC", "Gestures", "Other" ]),
    f("communication.helpful_words", "Important words or translations caregivers should know", :long_text),
    f("behaviour.temperament", "How would you describe your child’s temperament?", :multi_select, options: [ "Easygoing", "Cautious", "Energetic", "Shy", "Curious", "Sensitive" ]),
    f("behaviour.adult_interaction", "How does your child usually interact with adults?", :long_text),
    f("behaviour.peer_interaction", "How does your child usually interact with other children?", :long_text),
    f("behaviour.play_preference", "Does your child prefer playing alone, beside others, or in groups?", :multi_select, options: [ "Alone", "Beside others", "In groups" ]),
    f("behaviour.group_comfort", "Is your child comfortable in group situations?", :boolean),
    f("behaviour.frustration_expression", "How does your child express frustration or distress?", :long_text),
    f("behaviour.triggers", "Are there known triggers, fears, anxieties, or sensory sensitivities?", :boolean, sensitive: true),
    f("behaviour.calming_methods", "What helps your child feel calm and safe?", :long_text),
    f("behaviour.guidance_methods", "What behaviour-guidance or redirection methods work at home?", :long_text),
    f("behaviour.special_context", "Behaviours caregivers should understand in context", :long_text, sensitive: true),
    f("behaviour.social_goals", "Social or emotional goals caregivers can support", :long_text),
    f("behaviour.recent_stress", "Has your child experienced a recent loss, move, separation, or major stress?", :boolean, sensitive: true)
  ] end

  s("interests", "Interests, strengths, and learning", "development") do [
    f("interests.favourite_activities", "What activities does your child enjoy?", :multi_select, options: [ "Art", "Music", "Sport", "Movement", "Nature", "Construction", "Pretend play", "Sensory play", "Books" ]),
    f("interests.favourite_toys", "Toys or play materials your child enjoys", :long_text),
    f("interests.favourite_books_songs", "Books, songs, or stories your child enjoys", :long_text),
    f("interests.avoided_activities", "Activities your child avoids", :long_text),
    f("development.milestones", "Developmental milestones recently achieved", :long_text),
    f("development.focus_areas", "Developmental areas currently being supported", :long_text),
    f("development.self_help_skills", "Self-help skills your child practices", :multi_select, options: [ "Dressing", "Handwashing", "Tidying up", "Feeding self", "Putting on shoes" ]),
    f("development.family_goals", "What goals does your family have for your child?", :long_text),
    f("development.thrive_notes", "What else would help educators support your child?", :long_text)
  ] end

  s("culture", "Culture, religion, and inclusion", "more", "All optional. Share only what you want a provider to know.") do [
    f("culture.background", "Cultural background your family would like to share", :long_text, sensitive: true),
    f("culture.languages_to_include", "Languages you would like reflected in the program", :list),
    f("culture.holidays", "Cultural holidays or celebrations you would like included", :list),
    f("culture.religious_practices", "Religious practices the provider should respect", :long_text, sensitive: true),
    f("culture.conflicting_activities", "Activities, songs, stories, celebrations, or foods that conflict with family beliefs", :long_text, sensitive: true),
    f("culture.birthday_preference", "Does your family celebrate birthdays?", :single_select, options: [ "Yes", "No", "Prefer to discuss" ]),
    f("culture.family_participation", "Would your family like to share a cultural story, song, food, or activity?", :boolean),
    f("culture.inclusive_terms", "Names, terms, or identity information you want caregivers to use", :long_text, sensitive: true)
  ] end

  s("siblings", "Siblings", "more", "Used for waitlist priority at providers that favour siblings.", repeatable: true) do [
    f("full_name", "Sibling’s name"),
    f("date_of_birth", "Date of birth or age"),
    f("current_provider", "Currently enrolled with a provider you’re applying to?", :single_select, options: %w[Yes No]),
    f("alumni_provider", "Previously attended a provider you’re applying to?", :single_select, options: %w[Yes No])
  ] end

  s("family_context", "Family context relevant to care", "more", "Optional. Only include what directly affects safe care or transition.") do [
    f("family.household_context", "Caregiving or household information relevant to safe care", :long_text, sensitive: true),
    f("family.major_changes", "Family changes that may affect transition or behaviour", :long_text, sensitive: true)
  ] end

  s("priority", "Waitlist priority and eligibility", "more", "Some providers prioritise certain families. Answer what applies; we’ll only share what each provider asks for.") do [
    f("priority.transfer_child", "Is the child transferring or graduating from another program?", :boolean),
    f("priority.provider_staff", "Is a parent or guardian employed by the provider?", :boolean),
    f("priority.partner_employer", "Is a guardian employed by a priority organization (municipality, university, RCMP, etc.)?", :boolean),
    f("priority.local_resident", "Does the family live in a provider’s priority area?", :boolean),
    f("priority.local_worker", "Does a guardian work in a provider’s priority area?", :boolean),
    f("priority.linked_school", "Does the child attend a linked school?", :boolean),
    f("priority.support_program", "Does the family participate in a named support, housing, young-parent, newcomer, or community program?", :boolean, sensitive: true),
    f("priority.indigenous_affiliation", "Does a stated Indigenous-community priority apply?", :boolean, sensitive: true)
  ] end

  s("consents", "Reusable permissions", "more", "Each permission is separate and is confirmed again for every provider before you submit.") do [
    f("consent.emergency_medical", "Call a medical practitioner or ambulance if a parent cannot be reached", :consent),
    f("consent.release_to_authorized", "Release the child to an authorized person other than a parent", :consent),
    f("consent.walks", "Neighbourhood walks", :consent),
    f("consent.field_trips", "Field trips or outings", :consent),
    f("consent.sunscreen", "Sunscreen application", :consent),
    f("consent.first_aid", "First aid", :consent),
    f("consent.photo_private", "Photos for private classroom display or documentation", :consent),
    f("consent.photo_family_app", "Photos in a family-only newsletter or app", :consent),
    f("consent.photo_public", "Photos for public website or social media", :consent, hint: "Separate from the private emergency photo."),
    f("consent.electronic_communication", "Electronic communication", :consent)
  ] end

  SECTIONS = @sections.freeze

  def self.sections = SECTIONS
  def self.find(key) = SECTIONS.find { |s| s.key == key }
  def self.for_tab(tab) = SECTIONS.select { |s| s.tab == tab }
end
