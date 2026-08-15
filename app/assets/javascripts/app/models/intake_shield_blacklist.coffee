class App.IntakeShieldBlacklist extends App.Model
  @configure 'IntakeShieldBlacklist', 'pattern', 'note', 'active'
  @extend Spine.Model.Ajax
  @url: @apiPath + '/intake_shield_blacklists'
  @configure_attributes = [
    { name: 'pattern', display: __('Domain'), tag: 'input', type: 'text', limit: 250, null: false, info: __('example.com / @example.com = domain + subdomains; *.example.com = subdomains only.') },
    { name: 'note', display: __('Note'), tag: 'input', type: 'text', limit: 500, null: true },
    { name: 'active', display: __('Active'), tag: 'active', default: true },
  ]
  @configure_delete = true
  @configure_clone = true
  @configure_overview = [
    'pattern',
    'note',
    'active',
  ]

  @description = __('Disposable or otherwise untrusted domains. Matching addresses raise the spam score. When inbound drop is enabled, mail from these domains is not turned into users or tickets. Domains of deleted spam users are added automatically.')
