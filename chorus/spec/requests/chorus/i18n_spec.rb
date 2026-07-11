require "rails_helper"

RSpec.describe "Chorus i18n", type: :request do
  it "renders UI text through t() keys (English by default)" do
    get "/chorus/strategies"
    expect(response.body).to include(
      I18n.t("chorus.actions.new_model", model: Chorus::Strategy.model_name.human)
    )
  end

  it "ships English keys in the engine" do
    expect(I18n.t("chorus.actions.new", locale: :en)).to eq("New")
  end

  it "localizes the spine models (strategies, goals, artifacts)" do
    get "/chorus/strategies"
    expect(response.body).to include(
      I18n.t("chorus.actions.new_model", model: Chorus::Strategy.model_name.human)
    )

    get "/chorus/goals"
    expect(response.body).to include(
      I18n.t("chorus.actions.new_model", model: Chorus::Goal.model_name.human)
    )

    get "/chorus/artifacts"
    expect(response.body).to include(
      I18n.t("chorus.actions.new_model", model: Chorus::Artifact.model_name.human)
    )
  end

  it "switches to Spanish via ?locale=es" do
    get "/chorus/strategies?locale=es"
    expect(response.body).to include("Estrategias")

    get "/chorus/goals?locale=es"
    expect(response.body).to include("Objetivos")

    get "/chorus/artifacts?locale=es"
    expect(response.body).to include("Artefactos")
  end

  it "ships ONLY en.yml inside the engine (the host carries other locales)" do
    engine_locales = Dir[Chorus::Engine.root.join("config/locales/*.yml")].map { |f| File.basename(f) }
    expect(engine_locales).to eq([ "en.yml" ])
  end
end
