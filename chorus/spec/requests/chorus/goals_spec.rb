require "rails_helper"

RSpec.describe "Chorus::Goals", type: :request do
    let(:strategy) { create(:chorus_strategy) }

  describe "GET /chorus/goals" do
    it "renders the index" do
      create(:chorus_goal)
      get "/chorus/goals"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET new / show / edit" do
    it "renders each form" do
      record = create(:chorus_goal)
      get "/chorus/goals/new"
      expect(response).to have_http_status(:ok)
      get "/chorus/goals/#{record.id}"
      expect(response).to have_http_status(:ok)
      get "/chorus/goals/#{record.id}/edit"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /chorus/goals" do
    it "persists a new goal" do
      expect {
        post "/chorus/goals", params: { goal: { name: "Double revenue", status: "active", strategy_id: strategy.id } }
      }.to change(Chorus::Goal, :count).by(1)
      expect(response).to have_http_status(:redirect)
    end

    it "re-renders on invalid input" do
      post "/chorus/goals", params: { goal: { name: "" } }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /chorus/goals/:id" do
    it "updates the goal" do
      record = create(:chorus_goal)
      patch "/chorus/goals/#{record.id}", params: { goal: { name: "Renamed" } }
      expect(record.reload.name).to eq("Renamed")
    end
  end

  describe "DELETE /chorus/goals/:id" do
    it "destroys the goal" do
      record = create(:chorus_goal)
      expect {
        delete "/chorus/goals/#{record.id}"
      }.to change(Chorus::Goal, :count).by(-1)
    end
  end
end
