require "rails_helper"

RSpec.describe "Chorus::Artifacts", type: :request do
    let(:workspace) { create(:chorus_workspace) }

  describe "GET /chorus/artifacts" do
    it "renders the index" do
      create(:chorus_artifact)
      get "/chorus/artifacts"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET new / show / edit" do
    it "renders each form" do
      record = create(:chorus_artifact)
      get "/chorus/artifacts/new"
      expect(response).to have_http_status(:ok)
      get "/chorus/artifacts/#{record.id}"
      expect(response).to have_http_status(:ok)
      get "/chorus/artifacts/#{record.id}/edit"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /chorus/artifacts" do
    it "persists a new artifact" do
      expect {
        post "/chorus/artifacts", params: { artifact: { name: "app repo", kind: "git_repo", locator: "https://example.com/app.git", workspace_id: workspace.id } }
      }.to change(Chorus::Artifact, :count).by(1)
      expect(response).to have_http_status(:redirect)
    end

    it "re-renders on invalid input" do
      post "/chorus/artifacts", params: { artifact: { name: "" } }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /chorus/artifacts/:id" do
    it "updates the artifact" do
      record = create(:chorus_artifact)
      patch "/chorus/artifacts/#{record.id}", params: { artifact: { name: "Renamed" } }
      expect(record.reload.name).to eq("Renamed")
    end
  end

  describe "DELETE /chorus/artifacts/:id" do
    it "destroys the artifact" do
      record = create(:chorus_artifact)
      expect {
        delete "/chorus/artifacts/#{record.id}"
      }.to change(Chorus::Artifact, :count).by(-1)
    end
  end
end
