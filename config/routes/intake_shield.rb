Zammad::Application.routes.draw do
  api_path = Rails.configuration.api_path

  match api_path + '/intake_shield_whitelists',     to: 'intake_shield_whitelists#index',   via: :get
  match api_path + '/intake_shield_whitelists/:id', to: 'intake_shield_whitelists#show',    via: :get
  match api_path + '/intake_shield_whitelists',     to: 'intake_shield_whitelists#create',  via: :post
  match api_path + '/intake_shield_whitelists/:id', to: 'intake_shield_whitelists#update',  via: :put
  match api_path + '/intake_shield_whitelists/:id', to: 'intake_shield_whitelists#destroy', via: :delete

  match api_path + '/intake_shield_blacklists',     to: 'intake_shield_blacklists#index',   via: :get
  match api_path + '/intake_shield_blacklists/:id', to: 'intake_shield_blacklists#show',    via: :get
  match api_path + '/intake_shield_blacklists',     to: 'intake_shield_blacklists#create',  via: :post
  match api_path + '/intake_shield_blacklists/:id', to: 'intake_shield_blacklists#update',  via: :put
  match api_path + '/intake_shield_blacklists/:id', to: 'intake_shield_blacklists#destroy', via: :delete

  match api_path + '/intake_shield_keywords',       to: 'intake_shield_keywords#index',     via: :get
  match api_path + '/intake_shield_keywords/:id',   to: 'intake_shield_keywords#show',      via: :get
  match api_path + '/intake_shield_keywords',       to: 'intake_shield_keywords#create',    via: :post
  match api_path + '/intake_shield_keywords/:id',   to: 'intake_shield_keywords#update',    via: :put
  match api_path + '/intake_shield_keywords/:id',   to: 'intake_shield_keywords#destroy',   via: :delete

  match api_path + '/intake_shield_pending_deletions',              to: 'intake_shield_pending_deletions#index',     via: :get
  match api_path + '/intake_shield_pending_deletions/scan',         to: 'intake_shield_pending_deletions#scan',      via: :post
  match api_path + '/intake_shield_pending_deletions/execute_all',  to: 'intake_shield_pending_deletions#execute_all', via: :post
  match api_path + '/intake_shield_pending_deletions/:id/cancel',   to: 'intake_shield_pending_deletions#cancel',    via: :post
  match api_path + '/intake_shield_pending_deletions/:id/execute',  to: 'intake_shield_pending_deletions#execute',   via: :post
  match api_path + '/intake_shield_pending_deletions/:id/whitelist', to: 'intake_shield_pending_deletions#whitelist', via: :post

  match api_path + '/intake_shield_pending_tickets',                to: 'intake_shield_pending_tickets#index',       via: :get
  match api_path + '/intake_shield_pending_tickets/scan',           to: 'intake_shield_pending_tickets#scan',        via: :post
  match api_path + '/intake_shield_pending_tickets/execute_all',    to: 'intake_shield_pending_tickets#execute_all', via: :post
  match api_path + '/intake_shield_pending_tickets/:id/cancel',     to: 'intake_shield_pending_tickets#cancel',      via: :post
  match api_path + '/intake_shield_pending_tickets/:id/execute',    to: 'intake_shield_pending_tickets#execute',     via: :post

  match api_path + '/intake_shield/users/:id/mark_spam', to: 'intake_shield_users#mark_spam', via: :post

  match api_path + '/intake_shield/captcha_config',    to: 'intake_shield_captcha#configuration', via: :get
  match api_path + '/intake_shield/captcha_challenge', to: 'intake_shield_captcha#challenge',     via: :get
  match api_path + '/intake_shield/captcha_script',    to: 'intake_shield_captcha#script',        via: :get
end
