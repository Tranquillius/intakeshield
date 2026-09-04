# Adds "Mark as spam" to Admin → Manage → Users row actions (classic UI).
class App.IntakeShieldUserActions
  @ACTION_NAME: 'intakeShieldMarkSpam'

  @allowed: ->
    App.User.current()?.permission('admin.intake_shield')

  @available: (user) ->
    return false if !@allowed()
    return false if !user
    return false if user.id is 1
    return false if _.isEmpty(user.email)
    return false if @privileged(user)
    true

  @privileged: (user) ->
    return false if typeof user?.permission isnt 'function'
    user.permission('admin') || user.permission('ticket.agent')

  @emailDomain: (email) ->
    parts = (email || '').toString().split('@')
    return '' if parts.length < 2
    parts.pop().toString().trim().toLowerCase()

  @injectAction: (controller) ->
    return if controller.genericObject isnt 'User'
    return if !@allowed()

    pageData = controller.pageData
    return if !pageData

    pageData.tableExtend ||= {}
    actions = pageData.tableExtend.customActions ||= []
    return if _.find(actions, (action) -> action.name is App.IntakeShieldUserActions.ACTION_NAME)

    actions.push(
      name: 'intakeShieldMarkSpam'
      display: __('Mark as spam')
      icon: 'ignore'
      class: 'js-intake-shield-mark-spam'
      available: (user) -> App.IntakeShieldUserActions.available(user)
      callback: (id) -> App.IntakeShieldUserActions.confirm(id, controller)
    )

  @confirm: (id, controller) ->
    user = App.User.find(id)
    return if !user

    domain = @emailDomain(user.email)
    new App.ControllerConfirm(
      message:   App.i18n.translateContent(__('Add the domain %s to the IntakeShield blacklist? Matching users will be queued by the spam-user scan.'), domain)
      container: controller.el.closest('.content')
      callback:  => @submit(id)
    )

  @submit: (id) ->
    App.Ajax.request(
      id:   "intake_shield_mark_spam_#{id}"
      type: 'POST'
      url:  "#{App.Config.get('api_path') || '/api/v1'}/intake_shield/users/#{id}/mark_spam"
      success: (data) ->
        App.IntakeShieldUserActions.notifySuccess(data)
      error: (xhr) ->
        App.IntakeShieldUserActions.notifyError(xhr)
    )

  @notifySuccess: (data) ->
    domain = data?.domain || ''
    scheduled = data?.scan_stats?.scheduled || 0
    if data?.already_listed && data?.scan_scheduled
      msg = App.i18n.translateContent(__('Domain %s is already on the blacklist. %s matching user(s) were scheduled.'), domain, scheduled)
    else if data?.already_listed
      msg = App.i18n.translateContent(__('Domain %s is already on the blacklist.'), domain)
    else if data?.scan_scheduled
      msg = App.i18n.translateContent(__('Domain %s was added to the blacklist. %s matching user(s) were scheduled.'), domain, scheduled)
    else
      msg = App.i18n.translateContent(__('Domain %s was added to the blacklist. Enable IntakeShield to scan matching users.'), domain)

    App.Event.trigger 'notify',
      type:    'success'
      msg:     msg
      timeout: 4000

  @notifyError: (xhr) ->
    data = xhr?.responseJSON || {}
    msg = data.error_human
    if !msg
      msg = App.i18n.translateContent(@errorMessage(data.error) || __('Could not mark user as spam.'))

    App.Event.trigger 'notify',
      type:    'error'
      msg:     msg
      timeout: 4000

  @errorMessage: (code) ->
    switch code
      when 'system_user' then __('The system user cannot be marked as spam.')
      when 'no_email' then __('This user has no e-mail address.')
      when 'privileged' then __('Agents and admins cannot be marked as spam.')
      when 'never_disposable' then __('This e-mail domain cannot be added to the blacklist.')
      when 'user_not_found' then __('User could not be found.')
      else __('Could not mark user as spam.')

  @install: ->
    return if !App.ControllerGenericIndex
    return if App.ControllerGenericIndex.__intakeShieldUserActionsPatched

    App.ControllerGenericIndex.__intakeShieldUserActionsPatched = true
    original = App.ControllerGenericIndex::renderObjects
    App.ControllerGenericIndex::renderObjects = (objects) ->
      App.IntakeShieldUserActions.injectAction(@)
      original.call(@, objects)

App.IntakeShieldUserActions.install()
