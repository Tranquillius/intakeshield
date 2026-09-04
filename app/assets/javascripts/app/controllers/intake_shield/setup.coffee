# Map pre-tab hash URLs onto the grouped sidebar targets so bookmarks and
# ControllerNavSidebar highlighting (`/#{target}$`) keep working.
IntakeShieldLegacyTargets =
  whitelist:         { target: 'filters', tab: 'whitelist' }
  blacklist:         { target: 'filters', tab: 'blacklist' }
  keywords:          { target: 'filters', tab: 'keywords' }
  pending_deletions: { target: 'spam',    tab: 'users' }
  pending_tickets:   { target: 'spam',    tab: 'tickets' }

class App.IntakeShieldRouter extends App.ControllerPermanent
  @requiredPermission: ['admin.intake_shield']

  constructor: (params) ->
    super

    # check authentication
    @authenticateCheckRedirect()

    # reuse the admin task so the level2 navigation sidebar stays active
    App.TaskManager.execute(
      key:        'Manage'
      controller: 'Manage'
      params:     @normalizeParams(params)
      show:       true
      persistent: true
    )

  normalizeParams: (params) ->
    params = _.extend({}, params)
    if params.search_query
      params.search_query = decodeURIComponent(params.search_query)

    mapped = IntakeShieldLegacyTargets[params.target]
    if mapped
      params.tab = mapped.tab
      params.target = mapped.target
    params

# More specific routes last so Spine matches them first (unshift).
App.Config.set('intake_shield/:target', App.IntakeShieldRouter, 'Routes')
App.Config.set('intake_shield/:target/:page', App.IntakeShieldRouter, 'Routes')
App.Config.set('intake_shield/:target/:page/:search_query', App.IntakeShieldRouter, 'Routes')
App.Config.set('intake_shield/:target/:tab/:page', App.IntakeShieldRouter, 'Routes')
App.Config.set('intake_shield/:target/:tab/:page/:search_query', App.IntakeShieldRouter, 'Routes')

App.Config.set('IntakeShield', { prio: 2600, name: __('IntakeShield'), target: '#intake_shield', permission: ['admin.intake_shield'] }, 'NavBarAdmin')

# Compact two-column description list for pending detail modals.
do ->
  return if document.getElementById('intake-shield-styles')

  style = document.createElement('style')
  style.id = 'intake-shield-styles'
  style.textContent = '''
    .intake-shield-dl {
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 0.85rem 1.5rem;
      margin: 0;
    }
    .intake-shield-dl > div {
      display: grid;
      grid-template-columns: 9.5rem minmax(0, 1fr);
      gap: 0.2rem 0.75rem;
      align-items: start;
      min-width: 0;
    }
    .intake-shield-dl-row--wide {
      grid-column: 1 / -1;
    }
    .intake-shield-dl dt {
      margin: 0;
      font-weight: 600;
      line-height: 1.4;
    }
    .intake-shield-dl dd {
      margin: 0;
      min-width: 0;
      line-height: 1.4;
      overflow-wrap: anywhere;
    }
    .intake-shield-dl dd .list {
      margin: 0;
      padding-left: 1.1rem;
    }
    .intake-shield-dl-meta {
      display: block;
      opacity: 0.75;
      margin-top: 0.15rem;
    }
    @media (max-width: 640px) {
      .intake-shield-dl {
        grid-template-columns: 1fr;
      }
      .intake-shield-dl > div {
        grid-template-columns: 7.5rem minmax(0, 1fr);
      }
    }
    .js-intake-shield-captcha {
      margin: 0.75rem 0 1rem;
    }
    .js-intake-shield-altcha {
      display: flex;
      align-items: center;
      gap: 0.65rem;
      max-width: 22rem;
      padding: 0.65rem 0.8rem;
      border: 1px solid #cfd6dd;
      border-radius: 4px;
      background: #f8fafb;
      font-size: 13px;
      line-height: 1.3;
    }
    .js-intake-shield-altcha.is-verified {
      border-color: #8fbc8f;
      background: #f3faf3;
    }
    .js-intake-shield-altcha.is-error {
      border-color: #e0a0a0;
      background: #fdf6f6;
    }
    .js-intake-shield-altcha-mark {
      flex: 0 0 auto;
      width: 1.1rem;
      text-align: center;
    }
    .intake-shield-tab-intro {
      margin: 0.85rem 0 0.15rem;
    }
    .intake-shield-tab-intro .page-description {
      margin: 0 0 0.4rem;
    }
    .intake-shield-tab-intro .page-description:last-child {
      margin-bottom: 0;
    }
    .intake-shield-tab-actions {
      display: flex;
      flex-wrap: wrap;
      gap: 0.5rem;
      margin: 0.75rem 0 1rem;
    }
    .intake-shield-header-switch {
      display: flex;
      align-items: center;
      gap: 0.55rem;
    }
    .intake-shield-header-switch-label {
      font-size: 13px;
      font-weight: 600;
      line-height: 1.2;
    }
    .intake-shield-tab-body .js-description {
      display: none !important;
    }
    .intake-shield-tab-body > .page-header .page-header-title {
      display: none;
    }
    .intake-shield-tab-body > .page-header {
      min-height: 0;
      background: transparent;
      border: 0;
      padding-top: 0.65rem;
    }
    .intake-shield-tab-body > .page-content {
      padding-left: 0;
      padding-right: 0;
      padding-top: 0;
    }
    .tab-content > .tab-pane > .page-description {
      margin-top: 0.85rem;
      margin-bottom: 0;
    }
    .tab-content > .tab-pane > .page-header {
      min-height: 0;
      background: transparent;
      border: 0;
      padding-top: 0.65rem;
    }
    .js-intake-shield-mark-spam .icon,
    .js-intake-shield-mark-spam.icon {
      width: 16px;
      height: 16px;
    }
  '''
  document.head.appendChild(style)
