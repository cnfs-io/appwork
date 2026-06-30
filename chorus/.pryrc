# .pryrc

if defined?(Rails)

  def custom_console_boot_method = puts("Hello, Chorus world!")

  def_model_shortcuts "a", Chorus::Agent
  def_model_shortcuts "g", Chorus::Goal
  def_model_shortcuts "i", Chorus::Issue
  def_model_shortcuts "o", Chorus::Organization
  def_model_shortcuts "p", Chorus::Project
  def_model_shortcuts "r", Chorus::Role
  def_model_shortcuts "s", Chorus::Strategy
  def_model_shortcuts "w", Chorus::Workspace
end
