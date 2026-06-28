# .pryrc

if defined?(Rails)

  def custom_console_boot_method = puts("Hello, world!")

  def_model_shortcuts "b", Okf::Bundle
  # def_model_shortcuts "c", Okf::Concept
  # def_model_shortcuts "co", Okf::Consumption
  # def_model_shortcuts "d", Okf::Directory
  def_model_shortcuts "e", Okf::Entry
  # def_model_shortcuts "i", Okf::Index
  # def_model_shortcuts "l", Okf::Log
  # def_model_shortcuts "s", Okf::Schema

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
