require "fileutils"

# Committed fixtures are the source of truth; the seed copies them into a
# gitignored working dir so a run can mutate files without dirtying git.
# Destructive + idempotent by design: it resets the working copy each run.
FIXTURES = Rails.root.join("../fixtures/bundles")   # spec/fixtures/bundles
WORKDIR  = Rails.root.join("storage/bundles")       # gitignored, mutable

abort "Fixtures not found at #{FIXTURES}" unless FIXTURES.exist?

FileUtils.rm_rf(WORKDIR)
FileUtils.mkdir_p(WORKDIR)
FileUtils.cp_r("#{FIXTURES}/.", WORKDIR)

account = Account.create!(title: "Acme")

WORKDIR.children.select(&:directory?).each do |dir|
  account.bundles.create!(path: dir.to_s)   # after_create -> Sync -> concepts
end

# Strategy CLAIMS an existing concept from a bundle (ownership does not create
# the file — it points at one). This is what activates Sync's owned_concept_policy
# branch. See doc/plans/PLAN-cnfs-support-walker-and-cleanup.md Tier B4.
strategy = account.strategies.create!(title: "Q3 Expansion")
bundle   = account.bundles.find { |b| b.path.end_with?("acme") }
strategy.update!(concept: bundle.concepts.find_by!(path: "strategies/q3-expansion.md"))

puts "Seeded: #{account.bundles.count} bundles, #{Appwork::Okf::Concept.count} concepts, " \
     "#{Strategy.count} strategy owning a concept"
