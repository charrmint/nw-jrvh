# Reusable child profile screens. Only name and date of birth are stored (see ChildrenController);
# the question sections are front end only for now.
class ProfilesController < ApplicationController
  before_action :set_child
  before_action :set_section, only: %i[edit update]

  def show
    @tab = ProfileSchema::TABS.key?(params[:tab]) ? params[:tab] : "overview"
  end

  def edit; end

  # TODO(backend): persist params[:profile] for @child once profile storage exists.
  def update
    sections = ProfileSchema.sections
    next_section = sections[(sections.index(@section) || 0) + 1]
    if params[:commit_next] && next_section
      redirect_to edit_child_profile_path(@child, section: next_section.key), notice: "Saved (demo — not stored yet)."
    else
      redirect_to child_profile_path(@child), notice: "Saved (demo — not stored yet)."
    end
  end

  private

  def set_child
    @child = Current.user.children.find(params[:child_id])
  end

  def set_section
    @section = ProfileSchema.find(params[:section]) || ProfileSchema.sections.first
  end
end
