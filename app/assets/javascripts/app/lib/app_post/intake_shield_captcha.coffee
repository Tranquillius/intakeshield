# Injects honeypot + CAPTCHA widget into classic Signup and PasswordReset forms.
# Does not replace Zammad core controllers — patches render/submit after load.
class App.IntakeShieldCaptcha
  @config: null

  @enabled: ->
    value = App.Config.get('intake_shield_signup_captcha')
    return true if value is true || value is 'true' || value is 1 || value is '1'
    return false if value is false || value is 'false' || value is 0 || value is '0' || value is ''
    # Setting not yet in the frontend config: still ask the public endpoint.
    true

  @apiPath: ->
    App.Config.get('api_path') || '/api/v1'

  @mount: (el) ->
    return if !@enabled()
    return if !el?.length

    form = el.find('form')
    return if !form.length
    return if form.data('intakeShieldCaptchaMounted')

    form.data('intakeShieldCaptchaMounted', true)
    @fetchConfig (data) =>
      return if !data?.enabled
      @inject(form, data)

  @fetchConfig: (callback) ->
    if @config
      callback(@config)
      return

    App.Ajax.request(
      id:   'intake_shield_captcha_config'
      type: 'GET'
      url:  "#{@apiPath()}/intake_shield/captcha_config"
      success: (data) =>
        @config = data
        callback(data)
      error: ->
        callback({ enabled: false })
    )

  @inject: (form, data) ->
    form.find('.js-intake-shield-honeypot, .js-intake-shield-captcha').remove()

    @insertBeforeControls(form, @honeypotEl(data.honeypot)) if data.honeypot?.field
    @renderCaptcha(form, data.captcha) if data.captcha

  @honeypotEl: (honeypot) ->
    $("""
      <div class="js-intake-shield-honeypot" aria-hidden="true" style="position:absolute;left:-9999px;height:0;overflow:hidden;">
        <label>#{honeypot.field}</label>
        <input type="text" name="#{honeypot.field}" tabindex="-1" autocomplete="off">
      </div>
    """)

  @renderCaptcha: (form, captcha) ->
    container = $('<div class="js-intake-shield-captcha"></div>')
    @insertBeforeControls(form, container)
    @renderAltcha(container, captcha)

  @renderAltcha: (container, captcha) ->
    hidden = $("<input type=\"hidden\" name=\"#{captcha.response_field || 'altcha'}\">")
    box = $("""
      <div class="js-intake-shield-altcha" role="status" aria-live="polite">
        <span class="js-intake-shield-altcha-mark">…</span>
        <span class="js-intake-shield-altcha-label"></span>
      </div>
    """)
    box.find('.js-intake-shield-altcha-label').text(__('Verifying that you are human…'))
    container.append(box)
    container.append(hidden)
    @startAltcha(container, hidden, captcha)

  @startAltcha: (container, hidden, captcha) ->
    unless captcha.challenge_url
      @failAltcha(container, __('Captcha could not be loaded. Please reload the page.'))
      return

    fetch(captcha.challenge_url, { credentials: 'same-origin', headers: { Accept: 'application/json' } })
      .then (response) ->
        throw new Error('challenge') if !response.ok
        response.json()
      .then (challenge) =>
        @solveAltchaChallenge challenge, (number, took) =>
          payload =
            algorithm: challenge.algorithm
            challenge: challenge.challenge
            number:    number
            salt:      challenge.salt
            signature: challenge.signature
            took:      took
          hidden.val(btoa(JSON.stringify(payload)))
          @markAltchaVerified(container)
        , =>
          @failAltcha(container, __('Captcha could not be loaded. Please reload the page.'))
      .catch =>
        @failAltcha(container, __('Captcha could not be loaded. Please reload the page.'))

  @solveAltchaChallenge: (challenge, onSolved, onError) ->
    target = challenge?.challenge
    salt = challenge?.salt
    maxNumber = challenge?.maxnumber || challenge?.maxNumber || 50000
    unless target && salt? && window.crypto?.subtle
      onError()
      return

    encoder = new TextEncoder()
    started = Date.now()
    n = 0
    batchSize = 400

    toHex = (buffer) ->
      bytes = new Uint8Array(buffer)
      hex = ''
      i = 0
      while i < bytes.length
        hex += bytes[i].toString(16).padStart(2, '0')
        i += 1
      hex

    runBatch = ->
      end = Math.min(n + batchSize, maxNumber + 1)
      jobs = []
      while n < end
        jobs.push do (number = n) ->
          crypto.subtle.digest('SHA-256', encoder.encode(salt + String(number))).then (buf) ->
            { number: number, hash: toHex(buf) }
        n += 1

      Promise.all(jobs).then (results) ->
        found = null
        for result in results
          if result.hash is target
            found = result
            break
        if found
          onSolved(found.number, Date.now() - started)
          return
        if n > maxNumber
          onError()
          return
        setTimeout(runBatch, 0)
      .catch ->
        onError()

    runBatch()

  @markAltchaVerified: (container) ->
    box = container.find('.js-intake-shield-altcha')
    box.removeClass('is-error').addClass('is-verified')
    box.find('.js-intake-shield-altcha-mark').text('✓')
    box.find('.js-intake-shield-altcha-label').text(__('Verified'))
    container.find('.js-intake-shield-captcha-error').remove()

  @failAltcha: (container, message) ->
    box = container.find('.js-intake-shield-altcha')
    box.removeClass('is-verified').addClass('is-error')
    box.find('.js-intake-shield-altcha-mark').text('!')
    box.find('.js-intake-shield-altcha-label').text(message)
    @showError(container, message)

  @insertBeforeControls: (form, element) ->
    anchor = form.find('.form-controls, button[type=submit], .submit').first()
    if anchor.length
      element.insertBefore(anchor)
    else
      form.append(element)

  @copyWidgetValues: (form) ->
    form.find('altcha-widget').each ->
      value = @value
      return if !value
      input = form.find('.js-intake-shield-captcha input[type=hidden]').first()
      if !input.length
        name = 'altcha'
        form.append($("<input type=\"hidden\" name=\"#{name}\">"))
        input = form.find("input[name=\"#{name}\"]")
      input.val(value)

    form.find('.js-intake-shield-captcha textarea, .js-intake-shield-captcha input[type=hidden]').each ->
      el = $(@)
      return if el.val()
      name = el.attr('name')
      sibling = form.find("[name=\"#{name}\"]").not(el)
      el.val(sibling.val()) if sibling.val()

  @currentPayload: (form) ->
    @copyWidgetValues(form)
    value = ''
    form.find('.js-intake-shield-captcha input[type=hidden]').each ->
      value = $(@).val() if $(@).val()
    value

  @needsAltchaSolution: (form) ->
    form.find('.js-intake-shield-altcha').length && !@currentPayload(form)

  @showError: (target, message) ->
    el = if target?.jquery then target else $(target)
    return if !el.length
    el.find('.js-intake-shield-captcha-error').remove()
    el.append($("<p class=\"js-intake-shield-captcha-error\" style=\"color:#a32;margin:0.5rem 0 0;\">#{message}</p>"))

  @waitForAltcha: (form, done) ->
    if @currentPayload(form)
      done()
      return

    container = form.find('.js-intake-shield-captcha')
    unless form.find('.js-intake-shield-altcha').length
      @showError(container, __('Captcha could not be loaded. Please reload the page.'))
      return

    @showError(container, __('Captcha is still verifying. Please wait a moment.'))
    started = Date.now()
    timer = setInterval =>
      if @currentPayload(form)
        clearInterval(timer)
        container.find('.js-intake-shield-captcha-error').remove()
        done()
      else if Date.now() - started > 90000
        clearInterval(timer)
        @showError(container, __('Captcha could not be loaded. Please reload the page.'))
    , 200

  @ensureUserAttributes: (form) ->
    return if !App.User?.attributes
    form.find('.js-intake-shield-captcha [name], .js-intake-shield-honeypot [name]').each ->
      name = $(@).attr('name')
      return if !name
      return if name is 'altcha_widget'
      return if App.User.attributes.indexOf(name) isnt -1
      App.User.attributes.push(name)

  @patchController: (Klass) ->
    return if !Klass?.prototype?.render
    return if Klass.__intakeShieldCaptchaPatched
    Klass.__intakeShieldCaptchaPatched = true

    originalRender = Klass::render
    Klass::render = ->
      result = originalRender.apply(@, arguments)
      App.IntakeShieldCaptcha.mount(@el)
      result

    return if !Klass::submit
    originalSubmit = Klass::submit
    Klass::submit = (e) ->
      form = $(e.target).closest('form')
      form = @el.find('form') if !form.length
      App.IntakeShieldCaptcha.copyWidgetValues(form)
      App.IntakeShieldCaptcha.ensureUserAttributes(form)

      if App.IntakeShieldCaptcha.needsAltchaSolution(form) && !form.data('intakeShieldCaptchaReady')
        e.preventDefault()
        App.IntakeShieldCaptcha.waitForAltcha form, =>
          form.data('intakeShieldCaptchaReady', true)
          originalSubmit.call(@, e)
          form.removeData('intakeShieldCaptchaReady')
        return

      originalSubmit.apply(@, arguments)

  @install: ->
    @patchController(App.Config.get('signup', 'Routes'))
    @patchController(App.Config.get('password_reset', 'Routes'))
    @patchController(window.Signup)
    @patchController(window.PasswordReset)
    @patchController(App.Signup) if App.Signup
    @patchController(App.PasswordReset) if App.PasswordReset

App.IntakeShieldCaptcha.install()
