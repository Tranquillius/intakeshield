class IntakeShieldWhitelist extends App.ControllerSubContent
  @requiredPermission: 'admin.intake_shield'
  header: __('Whitelist')

  constructor: ->
    super
    App.IntakeShield.mountGenericIndex @,
      genericObject: 'IntakeShieldWhitelist'
      home: 'intake_shield_whitelists'
      object: __('Whitelist Entry')
      objects: __('Whitelist Entries')
      pagerBaseUrl: '#intake_shield/whitelist/'
      newButton: __('New Whitelist Entry')
      notes: [
        __('Exact address (user@example.com) or parent domain including subdomains (@example.com, example.com, *@example.com).')
        __('Trusted e-mail addresses and domains. Matching users receive the configured whitelist role and are never deleted automatically.')
      ]

  show: (params) =>
    App.IntakeShield.paginateGenericIndex(@, params)

App.Config.set('IntakeShieldWhitelist', { prio: 100, name: __('Whitelist'), parent: '#intake_shield', target: '#intake_shield/whitelist', controller: IntakeShieldWhitelist, permission: ['admin.intake_shield'] }, 'NavBarAdmin')
