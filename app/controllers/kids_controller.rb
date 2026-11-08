class KidsController < ApplicationController
  before_action :set_child, only: %i[show edit update]
  before_action :set_section, only: %i[new edit update create]

  def index
    @children = DemoData::CHILDREN
  end

  def show
    @tab = ProfileSchema::TABS.key?(params[:tab]) ? params[:tab] : "overview"
  end

  def new
    @child = nil
  end

  def edit; end

  # TODO(backend): persist params[:profile] against the signed-in user's child once models exist.
  def create
    redirect_to kids_path, notice: "Child profile saved (demo — not stored yet)."
  end

  def update
    sections = ProfileSchema.sections
    next_section = sections[(sections.index(@section) || 0) + 1]
    if params[:commit_next] && next_section
      redirect_to edit_kid_path(@child.id, section: next_section.key), notice: "Saved (demo — not stored yet)."
    else
      redirect_to kid_path(@child.id), notice: "Profile saved (demo — not stored yet)."
    end
  end

  private

  def set_child
    @child = DemoData.child(params[:id])
  end

  def set_section
    @section = ProfileSchema.find(params[:section] || params.dig(:profile, :_section)) || ProfileSchema.sections.first
  end
end
