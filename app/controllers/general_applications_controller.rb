class GeneralApplicationsController < ApplicationController
  before_action :set_application, only: %i[ edit update ]

  def index
    @applications = Current.user.general_applications.includes(:child).order(updated_at: :desc)
  end

  def new
    @application = Current.user.general_applications.build
    @application.child = Current.user.children.find_by(id: params[:child_id])
    if (previous = Current.user.general_applications.order(updated_at: :desc).first)
      %w[parent_first_name parent_last_name parent_email parent_phone parent_date_of_birth mailing_street mailing_city mailing_province mailing_postal_code mailing_country second_guardian_name second_guardian_email second_guardian_phone application_sms_consent affiliations_text affiliations_confirmed].each do |key|
        @application.public_send("#{key}=", previous.public_send(key))
      end
    else
      @application.parent_email = Current.user.email_address
      @application.parent_phone = Current.user.phone_number
      @application.mailing_province = "British Columbia"
      @application.mailing_country = "Canada"
    end
  end

  def create
    @application = Current.user.general_applications.build(application_params.except(:child_id))
    @application.child = Current.user.children.find_by(id: application_params[:child_id])

    if @application.save
      redirect_to general_applications_path, notice: "General application saved.", status: :see_other
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @application.update(application_params.except(:child_id))
      redirect_to general_applications_path, notice: "General application updated.", status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  private
    def set_application
      @application = Current.user.general_applications.find(params[:id])
    end

    def application_params
      params.require(:general_application).permit(
        :child_id, :preferred_start_date, :preferred_schedule, :school_name,
        :school_catchment, :support_required,
        :parent_first_name, :parent_last_name, :parent_email, :parent_phone,
        :parent_date_of_birth, :mailing_street, :mailing_city, :mailing_province,
        :mailing_postal_code, :mailing_country, :second_guardian_name,
        :second_guardian_email, :second_guardian_phone, :application_sms_consent,
        :affiliations_text, :affiliations_confirmed, :categories_confirmed,
        categories: []
      )
    end
end
