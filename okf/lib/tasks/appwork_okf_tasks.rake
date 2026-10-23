namespace :appwork do
  namespace :okf do
    desc "Reconcile all bundles (or BUNDLE=<id>) against disk"
    task sync: :environment do
      bundles = ENV["BUNDLE"] ? [ Appwork::Okf::Bundle.find(ENV["BUNDLE"]) ] : Appwork::Okf::Bundle.all
      bundles.each do |bundle|
        result = Appwork::Okf::Sync.call(bundle: bundle)
        puts "bundle=#{bundle.id} #{bundle.path} #{result}"
      end
    end

    desc "Watch all bundles (or BUNDLE=<id>) and sync on change (blocks; run as a dedicated process)"
    task listen: :environment do
      require "appwork/okf/listener"
      bundles = ENV["BUNDLE"] ? [ Appwork::Okf::Bundle.find(ENV["BUNDLE"]) ] : Appwork::Okf::Bundle.all
      Appwork::Okf::Listener.run(bundles: bundles)
    end
  end
end
