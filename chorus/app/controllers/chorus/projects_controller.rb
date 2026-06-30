module Chorus
  class ProjectsController < ApplicationController
    before_action :set_project, only: %i[show edit update destroy]

    def index
      @projects = Project.order(created_at: :desc)
    end

    def show
    end

    def new
      @project = Project.new
    end

    def edit
    end

    def create
      @project = Project.new(project_params)
      if @project.save
        redirect_to @project, notice: t("chorus.flash.created", model: Project.model_name.human)
      else
        render :new, status: :unprocessable_content
      end
    end

    def update
      if @project.update(project_params)
        redirect_to @project, notice: t("chorus.flash.updated", model: Project.model_name.human)
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @project.destroy
      notice = t("chorus.flash.destroyed", model: Project.model_name.human)
      respond_to do |format|
        # From the list turbo-frame: surgically remove the row. From anywhere
        # else (e.g. the show page): follow a redirect back to the index.
        format.turbo_stream do
          if request.headers["Turbo-Frame"].present?
            render turbo_stream: turbo_stream.remove(@project)
          else
            redirect_to projects_path, status: :see_other, notice: notice
          end
        end
        format.html { redirect_to projects_path, status: :see_other, notice: notice }
      end
    end

    private

    def set_project
      @project = Project.find(params[:id])
    end

    def project_params
      params.require(:project).permit(:goal_id, :name, :slug, :description, :status)
    end
  end
end
