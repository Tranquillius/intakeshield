class App.ControllerIntakeShieldSpam extends App.ControllerTabs
  @requiredPermission: 'admin.intake_shield'
  header: __('Spam')
  subHeader: __('IntakeShield')

  constructor: (params) ->
    params = App.IntakeShield.useSingleMainEl(params || {})
    super

    if params.tab is 'tickets'
      @Config.set('lastTab', '#is-spam-tickets')
    else if params.tab is 'users'
      @Config.set('lastTab', '#is-spam-users')
    else
      last = @Config.get('lastTab')
      if !last || String(last).indexOf('#is-spam-') isnt 0
        @Config.set('lastTab', '#is-spam-users')

    @tabs = [
      { name: __('Users'),   target: 'is-spam-users',   controller: App.ControllerIntakeShieldPendingDeletions }
      { name: __('Tickets'), target: 'is-spam-tickets', controller: App.ControllerIntakeShieldPendingTickets }
    ]
    @render()

App.Config.set('IntakeShieldSpam', { prio: 200, name: __('Spam'), parent: '#intake_shield', target: '#intake_shield/spam', controller: App.ControllerIntakeShieldSpam, permission: ['admin.intake_shield'] }, 'NavBarAdmin')
