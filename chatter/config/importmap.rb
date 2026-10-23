# Engine-shipped Stimulus controllers. Pinned under "controllers/appwork/chatter" so the
# host's existing `eagerLoadControllersFrom("controllers")` discovers them with
# identifiers like "appwork--chatter--messages". No npm/node — importmap only.
pin_all_from Appwork::Chatter::Engine.root.join("app/javascript/controllers/appwork/chatter"),
  under: "controllers/appwork/chatter"
