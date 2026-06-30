require "rails_helper"

RSpec.describe "Chorus::Projects", type: :request do
    let(:goal) { create(:chorus_goal) }

  describe "GET /chorus/projects" do
    it "renders the index" do
      create(:chorus_project)
      get "/chorus/projects"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET new / show / edit" do
    it "renders each form" do
      record = create(:chorus_project)
      get "/chorus/projects/new"
      expect(response).to have_http_status(:ok)
      get "/chorus/projects/#{record.id}"
      expect(response).to have_http_status(:ok)
      get "/chorus/projects/#{record.id}/edit"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /chorus/projects" do
    it "persists a new project" do
      expect {
        post "/chorus/projects", params: { project: { name: "Phoenix", status: "active", goal_id: goal.id } }
      }.to change(Chorus::Project, :count).by(1)
      expect(response).to have_http_status(:redirect)
    end

    it "re-renders on invalid input" do
      post "/chorus/projects", params: { project: { name: "" } }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /chorus/projects/:id" do
    it "updates the project" do
      record = create(:chorus_project)
      patch "/chorus/projects/#{record.id}", params: { project: { name: "Renamed" } }
      expect(record.reload.name).to eq("Renamed")
    end
  end

  describe "DELETE /chorus/projects/:id" do
    it "destroys the project" do
      record = create(:chorus_project)
      expect {
        delete "/chorus/projects/#{record.id}"
      }.to change(Chorus::Project, :count).by(-1)
    end
  end
end
