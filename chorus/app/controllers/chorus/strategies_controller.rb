module Chorus
  class StrategiesController < ApplicationController
    before_action :set_strategy, only: %i[show edit update destroy]

    def index
      @strategies = Strategy.order(created_at: :desc)
    end

    def show
    end

    def new
      @strategy = Strategy.new
    end

    def edit
    end

    def create
      @strategy = Strategy.new(strategy_params)
      if @strategy.save
        redirect_to @strategy, notice: t("chorus.flash.created", model: Strategy.model_name.human)
      else
        render :new, status: :unprocessable_content
      end
    end

    def update
      if @strategy.update(strategy_params)
        redirect_to @strategy, notice: t("chorus.flash.updated", model: Strategy.model_name.human)
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @strategy.destroy
      notice = t("chorus.flash.destroyed", model: Strategy.model_name.human)
      respond_to do |format|
        # From the list turbo-frame: surgically remove the row. From anywhere
        # else (e.g. the show page): follow a redirect back to the index.
        format.turbo_stream do
          if request.headers["Turbo-Frame"].present?
            render turbo_stream: turbo_stream.remove(@strategy)
          else
            redirect_to strategies_path, status: :see_other, notice: notice
          end
        end
        format.html { redirect_to strategies_path, status: :see_other, notice: notice }
      end
    end

    private

    def set_strategy
      @strategy = Strategy.find(params[:id])
    end

    def strategy_params
      params.require(:strategy).permit(:organization_id, :name, :description, :status)
    end
  end
end
