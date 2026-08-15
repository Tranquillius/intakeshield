class IntakeShieldSpam extends App.ControllerTabs
  @requiredPermission: 'admin.intake_shield'
  header: __('Spam')
  subHeader: __('IntakeShield')

  constructor: (params) ->
    super

    if params.tab is 'tickets'
      @Config.set('lastTab', '#is-spam-tickets')
    else if params.tab is 'users'
      @Config.set('lastTab', '#is-spam-users')

    @tabs = [
      { name: __('Users'),   target: 'is-spam-users',   controller: IntakeShieldPendingDeletions }
      { name: __('Tickets'), target: 'is-spam-tickets', controller: IntakeShieldPendingTickets }
    ]
    @render()

App.Config.set('IntakeShieldSpam', { prio: 200, name: __('Spam'), parent: '#intake_shield', target: '#intake_shield/spam', controller: IntakeShieldSpam, permission: ['admin.intake_shield'] }, 'NavBarAdmin')
