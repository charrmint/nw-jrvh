class ChildrenController < ApplicationController
  before_action :set_child, only: %i[ edit update ]

  def index
    @children = Current.user.children.order(:full_name)
  end

  def new
    @child = Current.user.children.build
  end

  def create
    @child = Current.user.children.build(child_params)

    if @child.save
      redirect_to children_path, notice: "Child profile created.", status: :see_other
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @child.update(child_params)
      redirect_to children_path, notice: "Child profile updated.", status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  private
    def set_child
      @child = Current.user.children.find(params[:id])
    end

    def child_params
      params.expect(child: %i[ full_name date_of_birth ])
    end
end
