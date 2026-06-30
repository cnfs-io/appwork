module Chorus
  class RolesController < ApplicationController
    before_action :set_role, only: %i[show edit update destroy]

    def index
      @roles = Role.order(created_at: :desc)
    end

    def show
    end

    def new
      @role = Role.new
    end

    def edit
    end

    def create
      @role = Role.new(role_params)
      if @role.save
        redirect_to @role, notice: t("chorus.flash.created", model: Role.model_name.human)
      else
        render :new, status: :unprocessable_content
      end
    end

    def update
      if @role.update(role_params)
        redirect_to @role, notice: t("chorus.flash.updated", model: Role.model_name.human)
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @role.destroy
      notice = t("chorus.flash.destroyed", model: Role.model_name.human)
      respond_to do |format|
        # From the list turbo-frame: surgically remove the row. From anywhere
        # else (e.g. the show page): follow a redirect back to the index.
        format.turbo_stream do
          if request.headers["Turbo-Frame"].present?
            render turbo_stream: turbo_stream.remove(@role)
          else
            redirect_to roles_path, status: :see_other, notice: notice
          end
        end
        format.html { redirect_to roles_path, status: :see_other, notice: notice }
      end
    end

    private

    def set_role
      @role = Role.find(params[:id])
    end

    def role_params
      params.require(:role).permit(:organization_id, :name, :description)
    end
  end
end
