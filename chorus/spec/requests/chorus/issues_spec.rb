require "rails_helper"

RSpec.describe "Chorus::Issues", type: :request do
    let(:project) { create(:chorus_project) }

  describe "GET /chorus/issues" do
    it "renders the index" do
      create(:chorus_issue)
      get "/chorus/issues"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET new / show / edit" do
    it "renders each form" do
      record = create(:chorus_issue)
      get "/chorus/issues/new"
      expect(response).to have_http_status(:ok)
      get "/chorus/issues/#{record.id}"
      expect(response).to have_http_status(:ok)
      get "/chorus/issues/#{record.id}/edit"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /chorus/issues" do
    it "persists a new issue" do
      expect {
        post "/chorus/issues", params: { issue: { title: "Ship it", status: "open", project_id: project.id } }
      }.to change(Chorus::Issue, :count).by(1)
      expect(response).to have_http_status(:redirect)
    end

    it "re-renders on invalid input" do
      post "/chorus/issues", params: { issue: { title: "" } }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /chorus/issues/:id" do
    it "updates the issue" do
      record = create(:chorus_issue)
      patch "/chorus/issues/#{record.id}", params: { issue: { title: "Renamed" } }
      expect(record.reload.title).to eq("Renamed")
    end
  end

  describe "DELETE /chorus/issues/:id" do
    it "destroys the issue" do
      record = create(:chorus_issue)
      expect {
        delete "/chorus/issues/#{record.id}"
      }.to change(Chorus::Issue, :count).by(-1)
    end
  end
end
