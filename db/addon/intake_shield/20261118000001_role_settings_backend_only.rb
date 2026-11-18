# Zammad's `rails generate zammad:setting_types` (run by package precompile)
# calls `options.keys` on every frontend select setting. The role pickers use
# `relation: 'Role'` without static options, which crashes the generator and
# aborts the asset build. The frontend never reads these via App.Config — the
# settings UI loads them through the Setting API — so mark them backend-only.
class RoleSettingsBackendOnly < ActiveRecord::Migration[7.0]
  NAMES = %w[
    intake_shield_whitelist_role_id
    intake_shield_whitelist_remove_role_ids
    intake_shield_candidate_role_id
  ].freeze

  def self.up
    Setting.where(name: NAMES, frontend: true).find_each do |setting|
      setting.update!(frontend: false)
    end
    Rails.cache.clear
  end

  def self.down
    Setting.where(name: NAMES).find_each do |setting|
      setting.update!(frontend: true)
    end
  end
end
