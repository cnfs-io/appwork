# frozen_string_literal: true

require "tmpdir"

# Builds a real file-backed OKF concept and claims it onto a consumer record, so
# a Workable's status accessor can be exercised end-to-end (status lives in the
# concept's custom_frontmatter and round-trips to the file). Mirrors OKF's own
# consumer_frontmatter_spec setup.
#
# Usage:
#   in_concept_root do
#     record = give_concept(create(:micro_manager_project))
#     record.status = "done"
#     record.concept.save!
#   end
module WorkableConceptHelper
  def in_concept_root
    Dir.mktmpdir("mm-workable") do |root|
      @concept_root = root
      yield
    end
  end

  def give_concept(record, rel: "c.md", frontmatter: "title: X\n", body: "body\n")
    dir  = File.join(@concept_root, "bundle")
    path = File.join(dir, rel)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, "---\n#{frontmatter}---\n#{body}")
    bundle = CnfsOkf::Bundle.create!(path: dir)
    record.update!(concept: bundle.concepts.find_by!(path: rel))
    record
  end
end
