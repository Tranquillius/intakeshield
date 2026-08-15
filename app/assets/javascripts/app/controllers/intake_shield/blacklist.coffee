class IntakeShieldBlacklist extends App.ControllerSubContent
  @requiredPermission: 'admin.intake_shield'
  header: __('Blacklist')

  constructor: ->
    super
    App.IntakeShield.mountGenericIndex @,
      genericObject: 'IntakeShieldBlacklist'
      home: 'intake_shield_blacklists'
      object: __('Blacklist Entry')
      objects: __('Blacklist Entries')
      pagerBaseUrl: '#intake_shield/filters/blacklist/'
      newButton: __('New Blacklist Entry')
      notes: [
        __('example.com / @example.com = domain + subdomains; *.example.com = subdomains only.')
        __('Disposable or otherwise untrusted domains. Matching addresses raise the spam score. When inbound drop is enabled, mail from these domains is not turned into users or tickets. Domains of deleted spam users are added automatically.')
      ]

  show: (params) =>
    App.IntakeShield.paginateGenericIndex(@, params)

