class BoardsController < ApplicationController
  def index
    @boards = CnfsUi::Board.all
  end

  def show
    @board = CnfsUi::Board.find(params[:id])
    # reposition_url is passed IN to the component (seam rule — the component
    # builds no route). It's the engine's mounted reposition path and becomes the
    # sortable controller's data-sortable-endpoint-value. The default renderer
    # wraps each placement's subject (a Gtd::Action) in Kanban::Card, which binds
    # only the content interface (title) — never OKF, never Gtd.
    @kanban = CnfsUi::Components::Kanban::Board.new(
      board: @board,
      reposition_url: cnfs_ui.reposition_placements_path
    )
  end
end
