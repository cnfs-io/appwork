module Okf
  class RootBundle < Bundle
    # A RootBundle is a Bundle with no parent; its `path` is absolute.
    # No behavior to add yet — the STI subclass exists so consumers can say
    # `owns_one_okf :root_bundle, class_name: "Okf::RootBundle"` and so future
    # root-specific behavior has a home. pathname's base case already covers it.
  end
end
