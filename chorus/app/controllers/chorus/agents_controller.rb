module Chorus
  class AgentsController < ApplicationController
    before_action :set_agent, only: %i[show edit update destroy]

    def index
      @agents = Agent.order(created_at: :desc)
    end

    def show
    end

    def new
      @agent = Agent.new
    end

    def edit
    end

    def create
      @agent = Agent.new(agent_params)
      if @agent.save
        redirect_to @agent, notice: t("chorus.flash.created", model: Agent.model_name.human)
      else
        render :new, status: :unprocessable_content
      end
    end

    def update
      if @agent.update(agent_params)
        redirect_to @agent, notice: t("chorus.flash.updated", model: Agent.model_name.human)
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @agent.destroy
      notice = t("chorus.flash.destroyed", model: Agent.model_name.human)
      respond_to do |format|
        # From the list turbo-frame: surgically remove the row. From anywhere
        # else (e.g. the show page): follow a redirect back to the index.
        format.turbo_stream do
          if request.headers["Turbo-Frame"].present?
            render turbo_stream: turbo_stream.remove(@agent)
          else
            redirect_to agents_path, status: :see_other, notice: notice
          end
        end
        format.html { redirect_to agents_path, status: :see_other, notice: notice }
      end
    end

    private

    def set_agent
      @agent = Agent.find(params[:id])
    end

    def agent_params
      params.require(:agent).permit(:organization_id, :role_id, :name, :kind)
    end
  end
end
