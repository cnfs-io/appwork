require "rails_helper"

RSpec.describe "Chorus::Organizations", type: :request do
  describe "GET /chorus/organizations" do
    it "renders the index" do
      create(:chorus_organization)
      get "/chorus/organizations"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET new / show / edit" do
    it "renders each form" do
      record = create(:chorus_organization)
      get "/chorus/organizations/new"
      expect(response).to have_http_status(:ok)
      get "/chorus/organizations/#{record.id}"
      expect(response).to have_http_status(:ok)
      get "/chorus/organizations/#{record.id}/edit"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /chorus/organizations" do
    it "persists a new organization" do
      expect {
        post "/chorus/organizations", params: { organization: { name: "Acme Chorus", slug: "acme" } }
      }.to change(Chorus::Organization, :count).by(1)
      expect(response).to have_http_status(:redirect)
    end

    it "re-renders on invalid input" do
      post "/chorus/organizations", params: { organization: { name: "" } }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /chorus/organizations/:id" do
    it "updates the organization" do
      record = create(:chorus_organization)
      patch "/chorus/organizations/#{record.id}", params: { organization: { name: "Renamed" } }
      expect(record.reload.name).to eq("Renamed")
    end
  end

  describe "DELETE /chorus/organizations/:id" do
    it "destroys the organization" do
      record = create(:chorus_organization)
      expect {
        delete "/chorus/organizations/#{record.id}"
      }.to change(Chorus::Organization, :count).by(-1)
    end
  end
end
