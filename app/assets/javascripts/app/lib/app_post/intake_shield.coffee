# Shared IntakeShield frontend helpers (reason i18n, generic index, pending tables).
App.IntakeShield =
  translateReasonList: (reasons) ->
    (App.IntakeShield.translateReason(reason) for reason in (reasons || []))

  translateReason: (reason) ->
    match = reason.match(/^(.*)(\s\(\+\d+\))$/)
    return "#{App.i18n.translateContent(match[1])}#{match[2]}" if match

    if (m = reason.match(/^cancelled:\s*manually cancelled by (.+)$/))
      return App.i18n.translateContent('cancelled: manually cancelled by %s', m[1])
    if (m = reason.match(/^cancelled:\s*whitelisted by (.+)$/))
      return App.i18n.translateContent('cancelled: whitelisted by %s', m[1])
    if (m = reason.match(/^cancelled:\s*(.+)$/))
      return "#{App.i18n.translateContent('cancelled')}: #{App.i18n.translateContent(m[1])}"

    App.i18n.translateContent(reason)

  withTranslatedReasons: (records) ->
    (records || []).map (record) ->
      record.reasons_list = App.IntakeShield.translateReasonList(record.reasons || [])
      record.reasons_display = record.reasons_list.join(', ')
      record

  # Factory for Whitelist / Blacklist / Keyword generic index pages.
  mountGenericIndex: (controller, options) ->
    controller.genericController = new App.ControllerGenericIndex(
      el: controller.el
      id: controller.id
      genericObject: options.genericObject
      defaultSortBy: 'pattern'
      pageData:
        home: options.home
        object: options.object
        objects: options.objects
        pagerAjax: true
        pagerBaseUrl: options.pagerBaseUrl
        pagerSelected: (controller.page || 1)
        pagerPerPage: 150
        navupdate: '#intake_shield'
        notes: options.notes
        buttons: [
          { name: options.newButton, 'data-type': 'new', class: 'btn--success' }
        ]
      container: controller.el.closest('.content')
    )

  paginateGenericIndex: (controller, params) ->
    for key, value of params
      if key isnt 'el' && key isnt 'shown' && key isnt 'match'
        controller[key] = value
    controller.genericController.paginate(controller.page || 1)

  # Shared ControllerTable wrapper for pending list pages.
  renderTable: (controller, options) ->
    el = controller.$(options.selector)
    return if !el.length

    config =
      el:             el
      tableId:        options.tableId
      class:          'table-hover'
      container:      controller.el.closest('.content')
      overview:       options.overview
      orderBy:        options.orderBy || 'execute_at'
      orderDirection: options.orderDirection || 'ASC'
      attribute_list: options.attribute_list
      objects:        options.objects
      bindRow:
        events:
          click: controller.showDetail

    if options.callbackAttributes
      config.callbackAttributes = options.callbackAttributes
    if options.customActions
      config.customActions = options.customActions

    new App.ControllerTable(config)

  confirmAction: (controller, message, callback) ->
    new App.ControllerConfirm(
      message:   message
      container: controller.el.closest('.content')
      callback:  callback
    )

  performMemberAction: (controller, id, action, message) ->
    controller.ajax(
      id:      "#{controller.apiActionPrefix}_#{action}_#{id}"
      type:    'POST'
      url:     "#{controller.apiPath}/#{controller.apiResource}/#{id}/#{action}"
      success: =>
        App.Event.trigger 'notify', {
          type:    'success'
          msg:     App.i18n.translateContent(message)
          timeout: 2500
        }
        controller.load()
    )

  runScan: (controller) ->
    controller.startLoading()
    controller.ajax(
      id:      "#{controller.apiActionPrefix}_scan"
      type:    'POST'
      url:     "#{controller.apiPath}/#{controller.apiResource}/scan"
      success: (data) =>
        controller.stopLoading()
        scheduled = (data.scan_stats && data.scan_stats.scheduled) || 0
        App.Event.trigger 'notify', {
          type:    'success'
          msg:     App.i18n.translateContent(__('Scan finished: %s scheduled.'), scheduled)
          timeout: 4000
        }
        controller.render(data)
      error:   =>
        controller.stopLoading()
        App.Event.trigger 'notify', {
          type:    'error'
          msg:     App.i18n.translateContent(__('Scan failed.'))
          timeout: 4000
        }
        controller.load()
    )

  runExecuteAll: (controller, confirmMessage, successMessage) ->
    App.IntakeShield.confirmAction controller, confirmMessage, =>
      controller.ajax(
        id:      "#{controller.apiActionPrefix}_execute_all"
        type:    'POST'
        url:     "#{controller.apiPath}/#{controller.apiResource}/execute_all"
        success: (data) =>
          App.Event.trigger 'notify', {
            type:    'success'
            msg:     App.i18n.translateContent(successMessage, data.executed || 0)
            timeout: 4000
          }
          controller.load()
        error: =>
          App.Event.trigger 'notify', {
            type:    'error'
            msg:     App.i18n.translateContent(__('Immediate deletion failed.'))
            timeout: 4000
          }
      )
