FactoryBot.define do
  # A hand-seeded category. The Concept -> Taxonomy scan that would morph these
  # is deferred (# 004), so specs seed taxonomy by hand. Randomized slug satisfies
  # the unique index.
  factory :chorus_taxonomy, class: "Chorus::Taxonomy" do
    sequence(:name) { |n| "Category #{n}" }
    sequence(:slug) { |n| "category-#{n}" }

    trait :with_parent do
      association :parent, factory: :chorus_taxonomy
    end
  end
end
