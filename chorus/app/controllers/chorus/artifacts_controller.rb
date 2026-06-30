module Chorus
  class ArtifactsController < ApplicationController
    before_action :set_artifact, only: %i[show edit update destroy]

    def index
      @artifacts = Artifact.order(created_at: :desc)
    end

    def show
    end

    def new
      @artifact = Artifact.new
    end

    def edit
    end

    def create
      @artifact = Artifact.new(artifact_params)
      if @artifact.save
        redirect_to @artifact, notice: t("chorus.flash.created", model: Artifact.model_name.human)
      else
        render :new, status: :unprocessable_content
      end
    end

    def update
      if @artifact.update(artifact_params)
        redirect_to @artifact, notice: t("chorus.flash.updated", model: Artifact.model_name.human)
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @artifact.destroy
      notice = t("chorus.flash.destroyed", model: Artifact.model_name.human)
      respond_to do |format|
        # From the list turbo-frame: surgically remove the row. From anywhere
        # else (e.g. the show page): follow a redirect back to the index.
        format.turbo_stream do
          if request.headers["Turbo-Frame"].present?
            render turbo_stream: turbo_stream.remove(@artifact)
          else
            redirect_to artifacts_path, status: :see_other, notice: notice
          end
        end
        format.html { redirect_to artifacts_path, status: :see_other, notice: notice }
      end
    end

    private

    def set_artifact
      @artifact = Artifact.find(params[:id])
    end

    def artifact_params
      params.require(:artifact).permit(:workspace_id, :name, :kind, :locator, :description)
    end
  end
end
