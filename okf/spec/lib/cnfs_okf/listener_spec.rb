require "rails_helper"
require "cnfs_okf/listener"
require "tmpdir"

# Deliberately THIN. The listener's only logic is routing — which bundle owns a
# path, and which paths changed. We do NOT spin up a real Listen thread or wait
# on filesystem events (that road is flaky). If a richer test feels necessary,
# that is a signal logic has leaked into the listener that belongs in Sync.
RSpec.describe CnfsOkf::Listener do
  def bundle_at(path)
    instance_double(CnfsOkf::Bundle, pathname: Pathname.new(path))
  end

  describe "#resolve" do
    it "maps an absolute path to [bundle, bundle-relative path]" do
      bundle   = bundle_at("/a/bundle")
      listener = described_class.new(bundles: [ bundle ])

      expect(listener.send(:resolve, "/a/bundle/notes/x.md")).to eq([ bundle, "notes/x.md" ])
    end

    it "gives an overlapping inner bundle its own file (longest prefix wins)" do
      outer    = bundle_at("/a/bundle")
      inner    = bundle_at("/a/bundle/inner")
      listener = described_class.new(bundles: [ outer, inner ])

      expect(listener.send(:resolve, "/a/bundle/inner/y.md")).to eq([ inner, "y.md" ])
    end

    it "drops a path under no bundle" do
      listener = described_class.new(bundles: [ bundle_at("/a/bundle") ])

      expect(listener.send(:resolve, "/elsewhere/z.md")).to be_nil
    end

    it "does not let a bundle claim a sibling with a shared prefix" do
      bundle   = bundle_at("/a/bundle")
      listener = described_class.new(bundles: [ bundle, bundle_at("/a/bundle-other") ])

      expect(listener.send(:resolve, "/a/bundle-other/x.md").first).not_to eq(bundle)
    end
  end

  describe "#route" do
    it "groups paths by bundle and calls Sync once per bundle" do
      bundle_a = bundle_at("/a")
      bundle_b = bundle_at("/b")
      listener = described_class.new(bundles: [ bundle_a, bundle_b ])

      allow(CnfsOkf::Sync).to receive(:call)

      listener.send(:route, [ "/a/one.md", "/a/two.md", "/b/three.md" ])

      expect(CnfsOkf::Sync).to have_received(:call)
        .with(bundle: bundle_a, paths: [ "one.md", "two.md" ]).once
      expect(CnfsOkf::Sync).to have_received(:call)
        .with(bundle: bundle_b, paths: [ "three.md" ]).once
    end

    it "delivers an overlapping-root event to the inner bundle exactly once" do
      outer    = bundle_at("/a/bundle")
      inner    = bundle_at("/a/bundle/inner")
      listener = described_class.new(bundles: [ outer, inner ])

      allow(CnfsOkf::Sync).to receive(:call)

      listener.send(:route, [ "/a/bundle/inner/y.md" ])

      expect(CnfsOkf::Sync).to have_received(:call)
        .with(bundle: inner, paths: [ "y.md" ]).once
      expect(CnfsOkf::Sync).not_to have_received(:call).with(bundle: outer, paths: anything)
    end

    it "logs and keeps watching when a Sync raises (never lets the callback die)" do
      listener = described_class.new(bundles: [ bundle_at("/a") ])
      allow(CnfsOkf::Sync).to receive(:call).and_raise("boom")

      expect { listener.send(:route, [ "/a/x.md" ]) }.not_to raise_error
    end
  end

  describe ".new" do
    it "raises when there are no bundles to watch" do
      expect { described_class.new(bundles: []) }.to raise_error(ArgumentError, /no bundles/)
    end

    it "raises when bundles is nil (Array(nil) is empty)" do
      expect { described_class.new(bundles: nil) }.to raise_error(ArgumentError, /no bundles/)
    end

    # Bundle.first hands in ONE record, not a collection — Array() must wrap it so
    # index_by does not blow up with NoMethodError.
    it "accepts a single bare record (not wrapped in an array)" do
      bundle   = bundle_at("/a/bundle")
      listener = nil

      expect { listener = described_class.new(bundles: bundle) }.not_to raise_error
      expect(listener.send(:resolve, "/a/bundle/x.md")).to eq([ bundle, "x.md" ])
    end
  end

  describe "#canonical" do
    around { |example| Dir.mktmpdir("okf-listener") { |root| @root = root; example.run } }

    # `listen` emits symlink-resolved paths; canonical must resolve bundle roots
    # the same way or longest-prefix routing never matches (the load-bearing bug).
    it "resolves a symlinked root to its realpath" do
      target = File.join(@root, "real")
      link   = File.join(@root, "link")
      FileUtils.mkdir_p(target)
      File.symlink(target, link)
      listener = described_class.new(bundles: [ bundle_at(target) ])

      expect(listener.send(:canonical, Pathname.new(link)))
        .to eq(Pathname.new(target).realpath.to_s)
    end

    it "returns a non-existent path as-is (test-double guard)" do
      listener = described_class.new(bundles: [ bundle_at("/a") ])

      expect(listener.send(:canonical, Pathname.new("/does/not/exist")))
        .to eq("/does/not/exist")
    end
  end
end
