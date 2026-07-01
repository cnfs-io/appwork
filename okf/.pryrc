# .pryrc

if false # defined?(Rails)


  def_model_shortcuts "b", Okf::Bundle
  def_model_shortcuts "c", Okf::Concept
  if Rails.root.to_s.end_with?('spec/dummy')
    def_model_shortcuts "g", Goal
    def_model_shortcuts "i", Issue
    def_model_shortcuts "o", Organization
    def_model_shortcuts "p", Project
    def_model_shortcuts "s", Strategy
  end

  def sync
    ob_a.each do |bundle|
      result = Okf::SyncService.new(bundle).call
      puts "[okf-sync] bundle=#{bundle.id} (#{bundle.name}): #{result.summary_line}"
      result.problems.each do |p|
        puts "[okf-sync]   #{p.kind} #{p.describe}"
      end
    end
  end

  # Register the before_reset hook to clean the documentation folder
  before_project_reset do
    target = Rails.root.join("tmp/bundles")
    return unless target.exist?

    # puts "🧹 Clearing project cache at #{target}..."
    target.rmtree
  end

  # Append custom sync tasks to the execution chain
  project_reset_tasks << "okf:sync"
end
