Rails.application.routes.draw do
  mount Appwork::Gtd::Engine => "/gtd"

  # partitia-ui mounted so its reposition endpoint resolves: the Board component is
  # handed `partitia_ui.reposition_placements_path` as `reposition_url:` (seam rule —
  # a component never builds a route). Drag PATCHes land here.
  mount Partitia::Ui::Engine => "/partitia-ui"

  # The three GTD boards over the same actions (plan 012). index lists them;
  # show renders the Kanban::Board Phlex component for one.
  resources :boards, only: %i[index show]

  root "boards#index"
end
