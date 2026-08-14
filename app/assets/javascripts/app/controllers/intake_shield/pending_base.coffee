# Shared base for Spam Users / Spam Tickets list pages.
class App.ControllerIntakeShieldPendingList extends App.ControllerSubContent
  @requiredPermission: 'admin.intake_shield'
  events:
    'click .js-refresh':     'refresh'
    'click .js-scan':        'scan'
    'click .js-execute-all': 'executeAll'

  # Subclasses set: apiResource, apiActionPrefix, listView, detailController

  constructor: ->
    super
    @recordsById = {}
    @load()

  load: =>
    @startLoading()
    @ajax(
      id:      @apiActionPrefix
      type:    'GET'
      url:     "#{@apiPath}/#{@apiResource}"
      success: (data) =>
        @stopLoading()
        @render(data)
      error:   =>
        @stopLoading()
        @render(records: [], failed: [])
    )

  render: (data) =>
    records = App.IntakeShield.withTranslatedReasons(data.records || [])
    failed  = App.IntakeShield.withTranslatedReasons(data.failed || [])
    @indexRecords(records.concat(failed))
    @html App.view(@listView)(
      records:    records
      failed:     failed
      scan_stats: data.scan_stats
    )
    @renderPendingTable(records)
    @renderFailedTable(failed)

  indexRecords: (records) =>
    @recordsById = {}
    for record in records
      @recordsById[record.id] = record

  showDetail: (id, e) =>
    return if e && $(e.target).closest('a, button, .btn, .dropdown, [data-table-action]').length

    e?.preventDefault?()
    record = @recordsById[id]
    return if !record

    new @detailController(
      record:    record
      container: @el.closest('.content')
    )

  confirmCancel: (id) =>
    App.IntakeShield.confirmAction @, __('Really cancel this deletion?'), =>
      App.IntakeShield.performMemberAction(@, id, 'cancel', __('Deletion cancelled.'))

  refresh: (e) =>
    e.preventDefault()
    @load()

  scan: (e) =>
    e.preventDefault()
    App.IntakeShield.runScan(@)

  executeAll: (e) =>
    e.preventDefault()
    App.IntakeShield.runExecuteAll(@, @executeAllConfirmMessage, @executeAllSuccessMessage)
