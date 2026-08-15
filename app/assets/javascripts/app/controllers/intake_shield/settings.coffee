# Explicit grouping — do not rely on Setting.area alone (stale/wrong areas
# would dump every IntakeShield setting into the first SettingsArea).
IntakeShieldSettingsSections =
  whitelist: [
    'intake_shield_whitelist_role_id'
    'intake_shield_whitelist_remove_role_ids'
    'intake_shield_whitelist_signup'
  ]
  captcha: [
    'intake_shield_signup_captcha'
  ]
  blacklist: [
    'intake_shield_drop_blacklisted_mail'
  ]
  cleanup: [
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
  engine: [
    'intake_shield_spam_engine'
    'intake_shield_spam_engine_backend'
    'intake_shield_spam_engine_host'
    'intake_shield_spam_engine_port'
    'intake_shield_spam_engine_timeout'
    'intake_shield_spam_engine_password'
  ]

class IntakeShieldSettingsPane extends App.Controller
  constructor: ->
    super
    @html App.view('intake_shield/settings_pane')(sections: @sections || [])
    for section, index in (@sections || [])
      @renderNames(@$(".js-settings-section[data-section='#{index}']"), section.names)

  renderNames: (container, names) ->
    return if !container.length
    container.empty()
    for name in (names || [])
      setting = App.Setting.findByAttribute('name', name)
      continue if !setting
      continue if setting.preferences?.disabled
      continue if setting.preferences?.hidden is true

      if setting.preferences?.controller && App[setting.preferences.controller]
        item = new App[setting.preferences.controller](setting: setting)
      else
        item = new App.SettingsAreaItem(setting: setting)
      container.append(item.el)

class IntakeShieldSettings extends App.ControllerTabs
  @requiredPermission: 'admin.intake_shield'
  header: __('Settings')
  subHeader: __('IntakeShield')
  headerSwitchName: 'intake-shield-activate'

  events:
    'click .nav-tabs [data-toggle="tab"]': 'tabRemember'
    'change .js-header-switch input': 'didChangeHeaderSwitch'

  elements:
    '.js-header-switch input': 'headerSwitchInput'

  constructor: ->
    super
    @tabs = []
    App.Setting.fetchFull(
      @didFetch
      force: true
    )

  didFetch: =>
    setting = App.Setting.findByAttribute('name', 'intake_shield_active')
    value = setting?.state_current?.value
    @headerSwitchChecked = value is true || value is 'true'
    @tabs = [
      {
        name: __('General')
        target: 'is-settings-general'
        controller: IntakeShieldSettingsPane
        params:
          sections: [
            {
              heading: __('Whitelist')
              description: __('Settings that control how trusted senders are handled.')
              names: IntakeShieldSettingsSections.whitelist
            }
            {
              heading: __('Captcha')
              description: __('Protect the classic sign-up form and password reset requests from automated abuse.')
              names: IntakeShieldSettingsSections.captcha
            }
          ]
      }
      {
        name: __('Blacklist')
        target: 'is-settings-blacklist'
        controller: IntakeShieldSettingsPane
        params:
          sections: [
            {
              description: __('Settings that control how inbound mail from blacklisted domains is handled.')
              names: IntakeShieldSettingsSections.blacklist
            }
          ]
      }
      {
        name: __('Cleanup')
        target: 'is-settings-cleanup'
        controller: IntakeShieldSettingsPane
        params:
          sections: [
            {
              description: __('Settings for detecting spam users/tickets and scheduling deletions.')
              names: IntakeShieldSettingsSections.cleanup
            }
          ]
      }
      {
        name: __('Spam Engine')
        target: 'is-settings-engine'
        controller: IntakeShieldSettingsPane
        params:
          sections: [
            {
              description: __('Optional scoring from gateway spam headers or a local SpamAssassin/Rspamd daemon. Those engines are not included in this package.')
              names: IntakeShieldSettingsSections.engine
            }
          ]
      }
    ]
    @render()
    @refreshElements()

  didChangeHeaderSwitch: (e) =>
    input = $(e.currentTarget)
    return if !input.length
    value = input.prop('checked')
    input.prop('disabled', true)
    try
      App.Setting.set('intake_shield_active', value,
        notify: true
        doneLocal: ->
          input.prop('disabled', false)
        failLocal: ->
          input.prop('checked', !value)
          input.prop('disabled', false)
      )
    catch
      input.prop('checked', !value)
      input.prop('disabled', false)

App.Config.set('IntakeShieldSettings', { prio: 300, name: __('Settings'), parent: '#intake_shield', target: '#intake_shield/settings', controller: IntakeShieldSettings, permission: ['admin.intake_shield'] }, 'NavBarAdmin')
