

def create_from_bundle(bun)
  # bundle = CnfsOkf::Bundle.find_or_create_by(path: "~/spikes/chorus/org")
  bundle = CnfsOkf::Bundle.find_or_create_by(path: bun.pathname.to_s)
  bundle.concepts.each do |concept|
    klass = concept.type&.classify&.safe_constantize
    owner = klass&.create(name: concept.description)
    concept.update(owner: owner) if owner
  end
end

src_path = Rails.root

# TODO Broken Bridge
# our org repo should have sources dir that contains concepts for each repo
# or a sources.md whose content is a list of repos
# we might need some internal convention for the formatting of documents
# NOTE
# - should probably look at how npx skills does it and maybe adopt their mechanism for installing skills

skills_repos = [ { name: :pocock, src: 'https://github.com/mattpocock/skills.git' } ]

# TODO Broken Bridge
# since OKF is a brand new standard most documents will not contain compliant frontmatter
# specifically it won't have a type and even if it does we dont' control it so
# we rather have to sense it or maybe we have custom code in the concept document
# that we could parse for what is mapped to what in the content
# maybe that is embedded yaml that says x dir is a skill, etc


skills_repos.each do |repo|
  Chorus::Source::Git.find_or_create_by(resource: repo[:src]).tap do |src|
    src.update(path: src_path.join("tmp/skills_dir/#{repo[:name]}"))
    src.fetch unless src.pathname.exist?
    bundle = CnfsOkf::Bundle.find_or_create_by(owner: src, path: src.path)
    create_from_bundle(bundle)
  end
end


# account = Account.find_or_create(name: "test")
# CnfsOkf::Bundle.create(owner: account)

msg = "seed complete"
puts msg
