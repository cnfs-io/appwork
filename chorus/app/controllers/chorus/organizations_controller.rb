module Chorus
  class OrganizationsController < ApplicationController
    before_action :set_organization, only: %i[show edit update destroy]

    def index
      @organizations = Organization.order(created_at: :desc)
    end

    def show
    end

    def new
      @organization = Organization.new
    end

    def edit
    end

    def create
      @organization = Organization.new(organization_params)
      if @organization.save
        redirect_to @organization, notice: t("chorus.flash.created", model: Organization.model_name.human)
      else
        render :new, status: :unprocessable_content
      end
    end

    def update
      if @organization.update(organization_params)
        redirect_to @organization, notice: t("chorus.flash.updated", model: Organization.model_name.human)
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @organization.destroy
      notice = t("chorus.flash.destroyed", model: Organization.model_name.human)
      respond_to do |format|
        # From the list turbo-frame: surgically remove the row. From anywhere
        # else (e.g. the show page): follow a redirect back to the index.
        format.turbo_stream do
          if request.headers["Turbo-Frame"].present?
            render turbo_stream: turbo_stream.remove(@organization)
          else
            redirect_to organizations_path, status: :see_other, notice: notice
          end
        end
        format.html { redirect_to organizations_path, status: :see_other, notice: notice }
      end
    end

    private

    def set_organization
      @organization = Organization.find(params[:id])
    end

    def organization_params
      params.require(:organization).permit(:name, :slug, :description)
    end
  end
end
