namespace :cnfs_okf do
  desc "Reconcile all bundles (or BUNDLE=<id>) against disk"
  task sync: :environment do
    bundles = ENV["BUNDLE"] ? [ CnfsOkf::Bundle.find(ENV["BUNDLE"]) ] : CnfsOkf::Bundle.all
    bundles.each do |bundle|
      result = CnfsOkf::Sync.call(bundle: bundle)
      puts "bundle=#{bundle.id} #{bundle.path} #{result}"
    end
  end

  desc "Watch all bundles (or BUNDLE=<id>) and sync on change (blocks; run as a dedicated process)"
  task listen: :environment do
    require "cnfs_okf/listener"
    bundles = ENV["BUNDLE"] ? [ CnfsOkf::Bundle.find(ENV["BUNDLE"]) ] : CnfsOkf::Bundle.all
    CnfsOkf::Listener.run(bundles: bundles)
  end
end
