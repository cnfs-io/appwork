module Chorus
  class WorkspacesController < ApplicationController
    before_action :set_workspace, only: %i[show edit update destroy]

    def index
      @workspaces = Workspace.order(created_at: :desc)
    end

    def show
    end

    def new
      @workspace = Workspace.new
    end

    def edit
    end

    def create
      @workspace = Workspace.new(workspace_params)
      if @workspace.save
        redirect_to @workspace, notice: t("chorus.flash.created", model: Workspace.model_name.human)
      else
        render :new, status: :unprocessable_content
      end
    end

    def update
      if @workspace.update(workspace_params)
        redirect_to @workspace, notice: t("chorus.flash.updated", model: Workspace.model_name.human)
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @workspace.destroy
      notice = t("chorus.flash.destroyed", model: Workspace.model_name.human)
      respond_to do |format|
        # From the list turbo-frame: surgically remove the row. From anywhere
        # else (e.g. the show page): follow a redirect back to the index.
        format.turbo_stream do
          if request.headers["Turbo-Frame"].present?
            render turbo_stream: turbo_stream.remove(@workspace)
          else
            redirect_to workspaces_path, status: :see_other, notice: notice
          end
        end
        format.html { redirect_to workspaces_path, status: :see_other, notice: notice }
      end
    end

    private

    def set_workspace
      @workspace = Workspace.find(params[:id])
    end

    def workspace_params
      params.require(:workspace).permit(:organization_id, :active_project_id, :name, :description)
    end
  end
end
