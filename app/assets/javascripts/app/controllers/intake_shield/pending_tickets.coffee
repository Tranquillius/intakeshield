class App.ControllerIntakeShieldPendingTicketDetail extends App.ControllerModal
  @requiredPermission: 'admin.intake_shield'
  buttonClose: true
  buttonCancel: false
  buttonSubmit: false
  head: __('Details')

  content: =>
    App.view('intake_shield/pending_ticket_detail')(record: @record)

class App.ControllerIntakeShieldPendingTickets extends App.ControllerIntakeShieldPendingList
  header: __('Spam Tickets')
  apiResource: 'intake_shield_pending_tickets'
  apiActionPrefix: 'intake_shield_pending_tickets'
  listView: 'intake_shield/pending_tickets'
  detailController: App.ControllerIntakeShieldPendingTicketDetail
  executeAllConfirmMessage: __('Really delete all pending tickets immediately via data privacy? This cannot be undone.')
  executeAllSuccessMessage: __('Immediate deletion started for %s tickets.')

  customerName: (ticket) ->
    customer = ticket && ticket.customer
    return '-' if !customer
    [customer.firstname, customer.lastname].filter(Boolean).join(' ') || customer.email || '-'

  tableObjects: (records, options = {}) ->
    records.map (record) =>
      ticket = record.ticket
      row =
        id:             record.id
        ticket_number:  (ticket && ticket.number) || '-'
        title:          (ticket && ticket.title) || '-'
        customer:       @customerName(ticket)
        reasons:        record.reasons_display || '-'
        ticket_created: (ticket && ticket.created_at) || null
        execute_at:     record.execute_at
        ticket_id:      ticket && ticket.id
      row.active = false if options.inactive
      row

  renderPendingTable: (records) =>
    App.IntakeShield.renderTable @,
      selector: '.js-table-pending'
      tableId:  'intake_shield_pending_tickets'
      overview: ['ticket_number', 'title', 'customer', 'reasons', 'ticket_created', 'execute_at']
      attribute_list: [
        { name: 'ticket_number', display: __('Ticket') }
        { name: 'title', display: __('Title') }
        { name: 'customer', display: __('Customer') }
        { name: 'reasons', display: __('Reasons') }
        { name: 'ticket_created', display: __('Ticket created'), tag: 'datetime' }
        { name: 'execute_at', display: __('Scheduled deletion'), tag: 'datetime' }
      ]
      objects: @tableObjects(records)
      callbackAttributes:
        ticket_number: [@ticketNumberLink]
      customActions: [
        {
          name: 'execute'
          display: __('Delete now')
          icon: 'trash'
          class: 'danger js-execute'
          callback: @confirmExecute
        }
        {
          name: 'cancel'
          display: __('Cancel Deletion')
          icon: 'cross'
          class: 'js-cancel'
          callback: @confirmCancel
        }
      ]

  ticketNumberLink: (value, object) ->
    return value if !object.ticket_id || !value || value is '-'
    "<a href=\"#ticket/zoom/#{object.ticket_id}\">#{App.Utils.htmlEscape(String(value))}</a>"

  renderFailedTable: (records) =>
    App.IntakeShield.renderTable @,
      selector:       '.js-table-failed'
      tableId:        'intake_shield_pending_tickets_failed'
      overview:       ['ticket_number', 'title', 'reasons', 'execute_at']
      orderDirection: 'DESC'
      attribute_list: [
        { name: 'ticket_number', display: __('Ticket') }
        { name: 'title', display: __('Title') }
        { name: 'reasons', display: __('Reasons') }
        { name: 'execute_at', display: __('Scheduled deletion'), tag: 'datetime' }
      ]
      objects: @tableObjects(records, inactive: true)

  confirmExecute: (id) =>
    App.IntakeShield.confirmAction @, __('Really delete this ticket immediately via data privacy? This cannot be undone.'), =>
      App.IntakeShield.performMemberAction(@, id, 'execute', __('Ticket deletion started.'))

