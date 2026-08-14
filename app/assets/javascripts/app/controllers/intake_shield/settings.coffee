# Explicit grouping — do not rely on Setting.area alone (stale/wrong areas
# would dump every IntakeShield setting into the first SettingsArea).
IntakeShieldSettingsSections =
  master: [
    'intake_shield_active'
  ]
  whitelist: [
    'intake_shield_whitelist_role_id'
    'intake_shield_whitelist_remove_role_ids'
  ]
  spam: [
    'intake_shield_candidate_role_id'
    'intake_shield_min_age_days'
    'intake_shield_max_age_days'
    'intake_shield_max_ticket_count'
    'intake_shield_delay_hours'
    'intake_shield_scoring_enabled'
    'intake_shield_spam_tag'
    'intake_shield_score_threshold'
    'intake_shield_score_weights'
  ]
  captcha: [
    'intake_shield_signup_captcha'
    'intake_shield_captcha_source'
  ]

class IntakeShieldSettings extends App.ControllerSubContent
  @requiredPermission: 'admin.intake_shield'
  header: __('Settings')

  constructor: ->
    super
    App.Setting.fetchFull(
      @render
      force: true
    )

  render: =>
    @html App.view('intake_shield/settings')()
    @renderSection('.js-settings-master', IntakeShieldSettingsSections.master)
    @renderSection('.js-settings-whitelist', IntakeShieldSettingsSections.whitelist)
    @renderSection('.js-settings-spam', IntakeShieldSettingsSections.spam)
    @renderSection('.js-settings-captcha', IntakeShieldSettingsSections.captcha)

  renderSection: (selector, names) =>
    container = @$(selector)
    container.empty()
    for name in names
      setting = App.Setting.findByAttribute('name', name)
      continue if !setting
      continue if setting.preferences?.disabled
      continue if setting.preferences?.hidden is true

      if setting.preferences?.controller && App[setting.preferences.controller]
        item = new App[setting.preferences.controller](setting: setting)
      else
        item = new App.SettingsAreaItem(setting: setting)
      container.append(item.el)

App.Config.set('IntakeShieldSettings', { prio: 300, name: __('Settings'), parent: '#intake_shield', target: '#intake_shield/settings', controller: IntakeShieldSettings, permission: ['admin.intake_shield'] }, 'NavBarAdmin')
