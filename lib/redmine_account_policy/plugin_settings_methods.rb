module PluginSettingsMethods
  # method to access plugin settings
  def set_plugin_setting(name, value)
    new_settings = Setting.plugin_redmine_account_policy
    new_settings[name] = value
    Setting.plugin_redmine_account_policy = new_settings
  end
end
