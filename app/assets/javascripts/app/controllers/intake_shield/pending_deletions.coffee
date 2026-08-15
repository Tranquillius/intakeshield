class IntakeShieldPendingDeletionDetail extends App.ControllerModal
  @requiredPermission: 'admin.intake_shield'
  buttonClose: true
  buttonCancel: false
  buttonSubmit: false
  head: __('Details')

  content: =>
    App.view('intake_shield/pending_deletion_detail')(record: @record)

class IntakeShieldPendingDeletions extends App.ControllerIntakeShieldPendingList
  header: __('Spam Users')
  apiResource: 'intake_shield_pending_deletions'
  apiActionPrefix: 'intake_shield_pending_deletions'
  listView: 'intake_shield/pending_deletions'
  detailController: IntakeShieldPendingDeletionDetail
  executeAllConfirmMessage: __('Really delete all pending users immediately via data privacy? This cannot be undone.')
  executeAllSuccessMessage: __('Immediate deletion started for %s users.')

  userName: (user) ->
    return '-' if !user
    [user.firstname, user.lastname].filter(Boolean).join(' ') || '-'

  tableObjects: (records, options = {}) ->
    records.map (record) =>
      user = record.user
      row =
        id:              record.id
        email:           (user && user.email) || '-'
        name:            @userName(user)
        score:           record.score
        reasons:         record.reasons_display || '-'
        account_created: (user && user.created_at) || null
        tickets_count:   if user && user.tickets_count != null && user.tickets_count != undefined then user.tickets_count else null
        execute_at:      record.execute_at
      row.active = false if options.inactive
      row

  renderPendingTable: (records) =>
    App.IntakeShield.renderTable @,
      selector: '.js-table-pending'
      tableId:  'intake_shield_pending_deletions'
      overview: ['email', 'name', 'score', 'reasons', 'account_created', 'tickets_count', 'execute_at']
      attribute_list: [
        { name: 'email', display: __('E-Mail') }
        { name: 'name', display: __('Name') }
        { name: 'score', display: __('Score'), tag: 'integer' }
        { name: 'reasons', display: __('Reasons') }
        { name: 'account_created', display: __('Account created'), tag: 'datetime' }
        { name: 'tickets_count', display: __('Tickets'), tag: 'integer' }
        { name: 'execute_at', display: __('Scheduled deletion'), tag: 'datetime' }
      ]
      objects: @tableObjects(records)
      customActions: [
        {
          name: 'execute'
          display: __('Delete now')
          icon: 'trash'
          class: 'danger js-execute'
          callback: @confirmExecute
        }
        {
          name: 'whitelist'
          display: __('Add to Whitelist')
          icon: 'checkmark'
          class: 'js-whitelist'
          callback: @confirmWhitelist
        }
        {
          name: 'cancel'
          display: __('Cancel Deletion')
          icon: 'cross'
          class: 'js-cancel'
          callback: @confirmCancel
        }
      ]

  renderFailedTable: (records) =>
    App.IntakeShield.renderTable @,
      selector:        '.js-table-failed'
      tableId:         'intake_shield_pending_deletions_failed'
      overview:        ['email', 'name', 'reasons', 'execute_at']
      orderDirection:  'DESC'
      attribute_list: [
        { name: 'email', display: __('E-Mail') }
        { name: 'name', display: __('Name') }
        { name: 'reasons', display: __('Reasons') }
        { name: 'execute_at', display: __('Scheduled deletion'), tag: 'datetime' }
      ]
      objects: @tableObjects(records, inactive: true)

  confirmExecute: (id) =>
    App.IntakeShield.confirmAction @, __('Really delete this user immediately via data privacy? This cannot be undone.'), =>
      App.IntakeShield.performMemberAction(@, id, 'execute', __('User deletion started.'))

  confirmWhitelist: (id) =>
    App.IntakeShield.confirmAction @, __('Really add this user to the whitelist and cancel the deletion?'), =>
      App.IntakeShield.performMemberAction(@, id, 'whitelist', __('User added to whitelist.'))

