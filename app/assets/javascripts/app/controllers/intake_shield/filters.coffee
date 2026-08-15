class IntakeShieldFilters extends App.ControllerSubContent
  @requiredPermission: 'admin.intake_shield'
  header: __('Filters')

  @tabKeys: ['whitelist', 'blacklist', 'keywords']

  constructor: (params) ->
    super
    @applyParams(params)
    @renderShell()
    @mountTab()

  show: (params) =>
    previousTab = @tab
    @applyParams(params)
    if @tab isnt previousTab || !@listController
      @unmountTab()
      @renderShell()
      @mountTab()
      return

    @listController.show(
      page: @page
      search_query: @searchQuery
    )

  applyParams: (params) ->
    params ||= {}
    @tab = @resolveTab(params)
    @page = @resolvePage(params)
    @searchQuery = params.search_query || params.searchQuery || ''

  resolveTab: (params) ->
    return params.tab if params.tab in @constructor.tabKeys
    return params.page if params.page in @constructor.tabKeys
    'whitelist'

  resolvePage: (params) ->
    if params.tab in @constructor.tabKeys
      page = parseInt(params.page, 10)
      return page if page > 0
      return 1
    if params.page in @constructor.tabKeys
      return 1
    page = parseInt(params.page, 10)
    return page if page > 0
    1

  renderShell: =>
    @html App.view('intake_shield/filters')(
      tabs: [
        { name: __('Whitelist'), href: '#intake_shield/filters/whitelist', active: @tab is 'whitelist' }
        { name: __('Blacklist'), href: '#intake_shield/filters/blacklist', active: @tab is 'blacklist' }
        { name: __('Keywords'),  href: '#intake_shield/filters/keywords',  active: @tab is 'keywords' }
      ]
    )

  mountTab: =>
    constructor = @tabController(@tab)
    return if !constructor

    @listController = new constructor(
      el: @$('.js-tab-body')
      page: @page
      searchQuery: @searchQuery
      search_query: @searchQuery
    )

  unmountTab: ->
    @listController?.genericController?.release?()
    @listController?.release?()
    @listController = null

  release: ->
    @unmountTab()
    super

  tabController: (key) ->
    switch key
      when 'whitelist' then IntakeShieldWhitelist
      when 'blacklist' then IntakeShieldBlacklist
      when 'keywords' then IntakeShieldKeyword

App.Config.set('IntakeShieldFilters', { prio: 100, name: __('Filters'), parent: '#intake_shield', target: '#intake_shield/filters', controller: IntakeShieldFilters, permission: ['admin.intake_shield'] }, 'NavBarAdmin')
