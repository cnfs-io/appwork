require "rails_helper"

RSpec.describe "Chorus::Agents", type: :request do
  describe "GET /chorus/agents" do
    xit "renders the index" do
      create(:chorus_agent)
      get "/chorus/agents"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET new / show / edit" do
    xit "renders each form" do
      record = create(:chorus_agent)
      get "/chorus/agents/new"
      expect(response).to have_http_status(:ok)
      get "/chorus/agents/#{record.id}"
      expect(response).to have_http_status(:ok)
      get "/chorus/agents/#{record.id}/edit"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /chorus/agents" do
    xit "persists a new agent" do
      expect {
        post "/chorus/agents", params: { agent: { name: "Echo", kind: "ai" } }
      }.to change(Chorus::Agent, :count).by(1)
      expect(response).to have_http_status(:redirect)
    end

    xit "re-renders on invalid input" do
      post "/chorus/agents", params: { agent: { name: "" } }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /chorus/agents/:id" do
    xit "updates the agent" do
      record = create(:chorus_agent)
      patch "/chorus/agents/#{record.id}", params: { agent: { name: "Renamed" } }
      expect(record.reload.name).to eq("Renamed")
    end
  end

  describe "DELETE /chorus/agents/:id" do
    xit "destroys the agent" do
      record = create(:chorus_agent)
      expect {
        delete "/chorus/agents/#{record.id}"
      }.to change(Chorus::Agent, :count).by(-1)
    end
  end
end
