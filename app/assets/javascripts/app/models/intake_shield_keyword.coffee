class App.IntakeShieldKeyword extends App.Model
  @configure 'IntakeShieldKeyword', 'pattern', 'note', 'active'
  @extend Spine.Model.Ajax
  @url: @apiPath + '/intake_shield_keywords'
  @configure_attributes = [
    { name: 'pattern', display: __('Keyword'), tag: 'input', type: 'text', limit: 250, null: false, info: __('Case-insensitive match in ticket title and first article body. Raises the spam score.') },
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

  @description = __('Spam keywords found in customer tickets raise the spam score.')
