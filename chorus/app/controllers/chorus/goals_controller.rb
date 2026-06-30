module Chorus
  class GoalsController < ApplicationController
    before_action :set_goal, only: %i[show edit update destroy]

    def index
      @goals = Goal.order(created_at: :desc)
    end

    def show
    end

    def new
      @goal = Goal.new
    end

    def edit
    end

    def create
      @goal = Goal.new(goal_params)
      if @goal.save
        redirect_to @goal, notice: t("chorus.flash.created", model: Goal.model_name.human)
      else
        render :new, status: :unprocessable_content
      end
    end

    def update
      if @goal.update(goal_params)
        redirect_to @goal, notice: t("chorus.flash.updated", model: Goal.model_name.human)
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @goal.destroy
      notice = t("chorus.flash.destroyed", model: Goal.model_name.human)
      respond_to do |format|
        # From the list turbo-frame: surgically remove the row. From anywhere
        # else (e.g. the show page): follow a redirect back to the index.
        format.turbo_stream do
          if request.headers["Turbo-Frame"].present?
            render turbo_stream: turbo_stream.remove(@goal)
          else
            redirect_to goals_path, status: :see_other, notice: notice
          end
        end
        format.html { redirect_to goals_path, status: :see_other, notice: notice }
      end
    end

    private

    def set_goal
      @goal = Goal.find(params[:id])
    end

    def goal_params
      params.require(:goal).permit(:strategy_id, :name, :description, :status)
    end
  end
end
