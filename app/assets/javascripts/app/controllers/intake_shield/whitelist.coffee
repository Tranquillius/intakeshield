class App.ControllerIntakeShieldWhitelist extends App.ControllerSubContent
  @requiredPermission: 'admin.intake_shield'
  header: __('Whitelist')
  @notes: [
    __('Exact address (user@example.com) or parent domain including subdomains (@example.com, example.com, *@example.com).')
    __('Trusted e-mail addresses and domains. Matching users receive the configured whitelist role and are never deleted automatically.')
    __('When "Use whitelist for self-registration" is enabled, only matching addresses can sign up.')
  ]

  constructor: ->
    super
    App.IntakeShield.mountGenericIndex @,
      genericObject: 'IntakeShieldWhitelist'
      home: 'intake_shield_whitelists'
      object: __('Whitelist Entry')
      objects: __('Whitelist Entries')
      pagerBaseUrl: '#intake_shield/filters/whitelist/'
      newButton: __('New Whitelist Entry')

  show: (params) =>
    App.IntakeShield.paginateGenericIndex(@, params)
