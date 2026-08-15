class IntakeShieldKeyword extends App.ControllerSubContent
  @requiredPermission: 'admin.intake_shield'
  header: __('Keywords')

  constructor: ->
    super
    App.IntakeShield.mountGenericIndex @,
      genericObject: 'IntakeShieldKeyword'
      home: 'intake_shield_keywords'
      object: __('Keyword')
      objects: __('Keywords')
      pagerBaseUrl: '#intake_shield/filters/keywords/'
      newButton: __('New Keyword')
      notes: [
        __('Case-insensitive match in ticket title and first article body. Raises the spam score.')
        __('Typical spam marketing phrases (e.g. product ads). Matching customer tickets raise the spam score.')
      ]

  show: (params) =>
    App.IntakeShield.paginateGenericIndex(@, params)

