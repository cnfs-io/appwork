module Chorus
  class IssuesController < ApplicationController
    before_action :set_issue, only: %i[show edit update destroy]

    def index
      @issues = Issue.order(created_at: :desc)
    end

    def show
    end

    def new
      @issue = Issue.new
    end

    def edit
    end

    def create
      @issue = Issue.new(issue_params)
      if @issue.save
        redirect_to @issue, notice: t("chorus.flash.created", model: Issue.model_name.human)
      else
        render :new, status: :unprocessable_content
      end
    end

    def update
      if @issue.update(issue_params)
        redirect_to @issue, notice: t("chorus.flash.updated", model: Issue.model_name.human)
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @issue.destroy
      notice = t("chorus.flash.destroyed", model: Issue.model_name.human)
      respond_to do |format|
        # From the list turbo-frame: surgically remove the row. From anywhere
        # else (e.g. the show page): follow a redirect back to the index.
        format.turbo_stream do
          if request.headers["Turbo-Frame"].present?
            render turbo_stream: turbo_stream.remove(@issue)
          else
            redirect_to issues_path, status: :see_other, notice: notice
          end
        end
        format.html { redirect_to issues_path, status: :see_other, notice: notice }
      end
    end

    private

    def set_issue
      @issue = Issue.find(params[:id])
    end

    def issue_params
      params.require(:issue).permit(:project_id, :agent_id, :title, :description, :status, :position)
    end
  end
end
