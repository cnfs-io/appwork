require "rails_helper"

RSpec.describe "Chorus::Workspaces", type: :request do
  describe "GET /chorus/workspaces" do
    it "renders the index" do
      create(:chorus_workspace)
      get "/chorus/workspaces"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET new / show / edit" do
    it "renders each form" do
      record = create(:chorus_workspace)
      get "/chorus/workspaces/new"
      expect(response).to have_http_status(:ok)
      get "/chorus/workspaces/#{record.id}"
      expect(response).to have_http_status(:ok)
      get "/chorus/workspaces/#{record.id}/edit"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /chorus/workspaces" do
    it "persists a new workspace" do
      expect {
        post "/chorus/workspaces", params: { workspace: { name: "Delivery" } }
      }.to change(Chorus::Workspace, :count).by(1)
      expect(response).to have_http_status(:redirect)
    end

    it "re-renders on invalid input" do
      post "/chorus/workspaces", params: { workspace: { name: "" } }
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "can set the active project slot" do
      project = create(:chorus_project)
      post "/chorus/workspaces", params: { workspace: { name: "Delivery", active_project_id: project.id } }
      expect(Chorus::Workspace.last.active_project).to eq(project)
    end
  end

  describe "PATCH /chorus/workspaces/:id" do
    it "updates the workspace" do
      record = create(:chorus_workspace)
      patch "/chorus/workspaces/#{record.id}", params: { workspace: { name: "Renamed" } }
      expect(record.reload.name).to eq("Renamed")
    end
  end

  describe "DELETE /chorus/workspaces/:id" do
    it "destroys the workspace" do
      record = create(:chorus_workspace)
      expect {
        delete "/chorus/workspaces/#{record.id}"
      }.to change(Chorus::Workspace, :count).by(-1)
    end
  end
end
