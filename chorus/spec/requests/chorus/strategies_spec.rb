require "rails_helper"

RSpec.describe "Chorus::Strategies", type: :request do
    let(:org) { create(:chorus_organization) }

  describe "GET /chorus/strategies" do
    it "renders the index" do
      create(:chorus_strategy)
      get "/chorus/strategies"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET new / show / edit" do
    it "renders each form" do
      record = create(:chorus_strategy)
      get "/chorus/strategies/new"
      expect(response).to have_http_status(:ok)
      get "/chorus/strategies/#{record.id}"
      expect(response).to have_http_status(:ok)
      get "/chorus/strategies/#{record.id}/edit"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /chorus/strategies" do
    it "persists a new strategy" do
      expect {
        post "/chorus/strategies", params: { strategy: { name: "Grow North", status: "active", organization_id: org.id } }
      }.to change(Chorus::Strategy, :count).by(1)
      expect(response).to have_http_status(:redirect)
    end

    it "re-renders on invalid input" do
      post "/chorus/strategies", params: { strategy: { name: "" } }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /chorus/strategies/:id" do
    it "updates the strategy" do
      record = create(:chorus_strategy)
      patch "/chorus/strategies/#{record.id}", params: { strategy: { name: "Renamed" } }
      expect(record.reload.name).to eq("Renamed")
    end
  end

  describe "DELETE /chorus/strategies/:id" do
    it "destroys the strategy" do
      record = create(:chorus_strategy)
      expect {
        delete "/chorus/strategies/#{record.id}"
      }.to change(Chorus::Strategy, :count).by(-1)
    end
  end
end
