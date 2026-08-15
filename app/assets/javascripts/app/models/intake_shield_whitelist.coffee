class App.IntakeShieldWhitelist extends App.Model
  @configure 'IntakeShieldWhitelist', 'pattern', 'note', 'active'
  @extend Spine.Model.Ajax
  @url: @apiPath + '/intake_shield_whitelists'
  @configure_attributes = [
    { name: 'pattern', display: __('Pattern'), tag: 'input', type: 'text', limit: 250, null: false, info: __('Exact address (user@example.com) or parent domain including subdomains (@example.com, example.com, *@example.com).') },
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
