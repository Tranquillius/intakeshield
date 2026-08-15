# Signup CAPTCHA is always self-hosted ALTCHA; drop the source setting.
class RemoveCaptchaSource < ActiveRecord::Migration[7.0]
  def self.up
    Setting.find_by(name: 'intake_shield_captcha_source')&.destroy

    begin
      load File.expand_path('support/de_translations.rb', __dir__)
      IntakeShieldDeTranslations.apply!
    rescue StandardError => e
      Rails.logger.error "IntakeShield translations sync skipped: #{e.class}: #{e.message}"
    end

    Rails.cache.clear
  end

  def self.down
    Setting.create_if_not_exists(
      title:       __('Captcha Source'),
      name:        'intake_shield_captcha_source',
      area:        'IntakeShield::Captcha',
      description: __('ALTCHA is self-hosted and needs no keys. Form channel reuses the CAPTCHA already configured under Channels → Form.'),
      options:     {
        form: [
          {
            display: '',
            null:    false,
            name:    'intake_shield_captcha_source',
            tag:     'select',
            options: {
              'altcha'       => 'ALTCHA (self-hosted)',
              'form_channel' => 'Form channel',
            },
          },
        ],
      },
      preferences: {
        prio:       2010,
        permission: ['admin.intake_shield'],
      },
      state:       'altcha',
      frontend:    true
    )
  end
end
