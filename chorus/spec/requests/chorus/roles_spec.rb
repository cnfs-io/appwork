require "rails_helper"

RSpec.describe "Chorus::Roles", type: :request do
  describe "GET /chorus/roles" do
    it "renders the index" do
      create(:chorus_role)
      get "/chorus/roles"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET new / show / edit" do
    it "renders each form" do
      record = create(:chorus_role)
      get "/chorus/roles/new"
      expect(response).to have_http_status(:ok)
      get "/chorus/roles/#{record.id}"
      expect(response).to have_http_status(:ok)
      get "/chorus/roles/#{record.id}/edit"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /chorus/roles" do
    it "persists a new role" do
      expect {
        post "/chorus/roles", params: { role: { name: "Coordinator" } }
      }.to change(Chorus::Role, :count).by(1)
      expect(response).to have_http_status(:redirect)
    end

    it "re-renders on invalid input" do
      post "/chorus/roles", params: { role: { name: "" } }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /chorus/roles/:id" do
    it "updates the role" do
      record = create(:chorus_role)
      patch "/chorus/roles/#{record.id}", params: { role: { name: "Renamed" } }
      expect(record.reload.name).to eq("Renamed")
    end
  end

  describe "DELETE /chorus/roles/:id" do
    it "destroys the role" do
      record = create(:chorus_role)
      expect {
        delete "/chorus/roles/#{record.id}"
      }.to change(Chorus::Role, :count).by(-1)
    end
  end
end
