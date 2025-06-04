angular.module('taigaContrib.drawio', [])
.run [
  '$http', '$timeout', '$compile', '$document', '$window', '$rootScope', '$location'
  ($http, $timeout, $compile, $document, $window, $rootScope, $location) ->
    drawioHost = 'https://embed.diagrams.net'
    attachmentsByName = {}

    getSlug = ->
      parts = $window.location.pathname.split('/')
      if parts.length > 2 then parts[2] else null

    fetchAttachments = (slug) ->
      $http.get("/api/v1/projects/by_slug?slug=#{slug}")
      .then (res) ->
        projectId = res.data.id
        return $http.get("/api/v1/userstories/attachments?project=#{projectId}")
      .then (res) ->
        attachmentsByName = {}
        for att in res.data
          if att.name.endsWith('.xml')
            attachmentsByName[att.name] = att.id

        insertButtons()
        insertCreateDiagramButton()

    insertButtons = ->
      links = $document[0].querySelectorAll('a[href*="/media/attachment"]')
      for link in links
        filename = link.textContent.trim()
        if filename.endsWith('.xml') and not link.parentElement.querySelector('.drawio-btn')
          attachmentId = attachmentsByName[filename]
          insertButtonAfterLink(link, attachmentId)

    insertButtonAfterLink = (link, attachmentId) ->
      # Edit button
      editBtn = angular.element("<button class='drawio-btn' style='margin-left: 10px; background: #83eede; color: #000; border: none; border-radius: 4px; cursor: pointer; transition: background 0.3s ease;'>Редактировать в Draw.io</button>")

      editBtn.on 'mouseenter', -> editBtn.css('background', '#008aa8')
      editBtn.on 'mouseleave', -> editBtn.css('background', '#83eede')
      editBtn.on 'click', -> openDrawioEditor(attachmentId)

      # AI Generate button
      aiBtn = angular.element("<button class='drawio-btn' style='margin-left: 10px; background: #83eede; color: #000; border: none; border-radius: 4px; cursor: pointer; transition: background 0.3s ease;'>Сгенерировать с помощью ИИ</button>")

      aiBtn.on 'mouseenter', -> aiBtn.css('background', '#008aa8')
      aiBtn.on 'mouseleave', -> aiBtn.css('background', '#83eede')
      aiBtn.on 'click', -> showAIPromptModal(attachmentId)

      # Append both buttons
      angular.element(link).after(editBtn)
      angular.element(link).after(aiBtn)

    showAIPromptModal = (attachmentId) ->
      modal = angular.element("""
        <div id="ai-prompt-modal" style="position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,0.5); z-index: 10000; display: flex; justify-content: center; align-items: center;">
          <div style="background: white; padding: 20px; border-radius: 8px; width: 400px;">
            <h3 style="margin-top: 0;">Генерация диаграммы с помощью ИИ</h3>
            <p>Введите описание диаграммы:</p>
            <textarea id="ai-prompt-input" style="width: 100%; height: 150px; padding: 5px; margin-bottom: 10px;" placeholder="Например: Схема работы интернет-магазина с пользователем, корзиной и платежной системой"></textarea>
            <div id="loading-spinner" style="display: none; text-align: center; margin: 10px 0;">
              <div style="border: 4px solid #f3f3f3; border-top: 4px solid #3498db; border-radius: 50%; width: 30px; height: 30px; animation: spin 1s linear infinite; display: inline-block;"></div>
              <p>Генерация диаграммы...</p>
            </div>
            <div style="margin-top: 15px; text-align: right;">
              <button id="cancel-ai" style="margin-right: 10px;">Отмена</button>
              <button id="submit-ai">ОК</button>
            </div>
          </div>
        </div>
      """)

      # Add CSS for spinner animation
      spinnerStyle = angular.element("""
        <style>
          @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
          }
        </style>
      """)
      angular.element($document[0].head).append(spinnerStyle)
      angular.element($document[0].body).append(modal)

      $document[0].querySelector('#cancel-ai').onclick = -> modal.remove()
      $document[0].querySelector('#submit-ai').onclick = ->
        prompt = $document[0].querySelector('#ai-prompt-input').value.trim()
        if prompt
          # Show loading spinner
          angular.element($document[0].querySelector('#loading-spinner')).css('display', 'block')
          # Disable buttons
          angular.element($document[0].querySelector('#cancel-ai')).prop('disabled', true)
          angular.element($document[0].querySelector('#submit-ai')).prop('disabled', true)

          # Send request to generate diagram
          $http.post("/api/v1/drawio/#{attachmentId}/generate/", { prompt: prompt })
            .then (res) ->
              modal.remove()
              alert("Диаграмма успешно сгенерирована!")
              $timeout((-> $window.location.reload()), 500)
            .catch (err) ->
              modal.remove()
              alert("Ошибка при генерации диаграммы: " + JSON.stringify(err))
            .finally ->
              # Hide loading spinner and enable buttons (just in case)
              angular.element($document[0].querySelector('#loading-spinner')).css('display', 'none')
              angular.element($document[0].querySelector('#cancel-ai')).prop('disabled', false)
              angular.element($document[0].querySelector('#submit-ai')).prop('disabled', false)


    openDrawioEditor = (attachmentId) ->
      $http.get("/api/v1/drawio/#{attachmentId}/raw/")
      .then (res) ->
        xmlData = res.data.xml_data

        drawioWindow = window.open(
          "#{drawioHost}?embed=1&proto=json"
          "_blank"
          "width=1200,height=800"
        )

        handler = (evt) ->
          return unless evt.source == drawioWindow
          try data = JSON.parse(evt.data)
          catch then return

          if data.event == 'init'
            drawioWindow.postMessage JSON.stringify(
              action: 'load'
              autosave: 1
              xml: xmlData
            ), '*'

          else if data.event == 'save'
            $http.post("/api/v1/drawio/#{attachmentId}/", { xml_data: data.xml })
            .then ->
              alert("Файл успешно сохранен!")
            .catch (err) ->
              alert("Ошибка при сохранении: " + JSON.stringify(err))

          else if data.event == 'exit'
            drawioWindow.postMessage JSON.stringify({ action: 'exit' }), '*'
            window.removeEventListener 'message', handler

        window.addEventListener 'message', handler
      .catch (err) ->
        alert("Ошибка при загрузке XML: " + JSON.stringify(err))

    insertCreateDiagramButton = ->
      sidebar = $document[0].querySelector('.sidebar.ticket-data')
      return unless sidebar && !$document[0].querySelector('#create-diagram-btn')

      btn = angular.element """
        <button id='create-diagram-btn'
                style='margin-top: 20px;
                       background: #5D6D7E;
                       color: white;
                       padding: 8px 12px;
                       border: none;
                       border-radius: 4px;
                       cursor: pointer;
                       width: calc(100% - 24px);
                       font-size: 14px;
                       transition: background 0.3s;
                       display: flex;
                       align-items: center;
                       justify-content: center;'>
          <i class='icon icon-add' style='margin-right: 8px;'></i>
          Создать диаграмму Draw.io
        </button>
      """

      btn.on 'click', -> showCreateDiagramModal()
      angular.element(sidebar).append(btn)

      btn.on 'mouseenter', -> angular.element(this).css('background', '#4A5A6A')
      btn.on 'mouseleave', -> angular.element(this).css('background', '#5D6D7E')


    showCreateDiagramModal = ->
      modal = angular.element("""
        <div id="create-diagram-modal" style="position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,0.5); z-index: 10000; display: flex; justify-content: center; align-items: center;">
          <div style="background: white; padding: 20px; border-radius: 8px; width: 300px;">
            <h3 style="margin-top: 0;">Имя диаграммы</h3>
            <input id="diagram-filename" type="text" style="width: 100%; padding: 5px;" placeholder="example.xml" />
            <div style="margin-top: 15px; text-align: right;">
              <button id="cancel-diagram" style="margin-right: 10px;">Отмена</button>
              <button id="create-diagram">Создать</button>
            </div>
          </div>
        </div>
      """)
      angular.element($document[0].body).append(modal)

      $document[0].querySelector('#cancel-diagram').onclick = -> modal.remove()
      $document[0].querySelector('#create-diagram').onclick = ->
        filename = $document[0].querySelector('#diagram-filename').value.trim()
        if not filename.endsWith('.xml')
          filename += '.xml'
        modal.remove()
        createEmptyDiagram(filename)

    defaultXml = ->
      """<?xml version="1.0" encoding="UTF-8"?>
         <mxfile host="app.diagrams.net" agent="Mozilla/5.0" version="27.0.6">
           <diagram name="Страница — 1" id="">
             <mxGraphModel dx="980" dy="534" grid="1" gridSize="10" guides="1" tooltips="1" connect="1" arrows="1" fold="1" page="1" pageScale="1" pageWidth="827" pageHeight="1169" math="0" shadow="0">
               <root>
                 <mxCell id="0" />
                 <mxCell id="1" parent="0" />
               </root>
             </mxGraphModel>
           </diagram>
         </mxfile>
      """

    createEmptyDiagram = (filename) ->
      slug = getSlug()
      return unless slug?

      $http.get("/api/v1/projects/by_slug?slug=#{slug}")
      .then (res) ->
        projectId = res.data.id
        objectId = projectId

        xml = defaultXml()
        blob = new Blob([xml], { type: 'application/xml' })

        formData = new FormData()
        formData.append("object_id", objectId)
        formData.append("project", projectId)
        formData.append("attached_file", blob, filename)
        formData.append("description", "Empty diagram created from Draw.io")
        formData.append("is_deprecated", "false")

        $http.post("http://localhost:9000/api/v1/userstories/attachments", formData,
          headers: { 'Content-Type': undefined }
          transformRequest: angular.identity
        ).then (res) ->
          alert("Диаграмма создана: " + filename)
          $timeout((-> $window.location.reload()), 500)

        .catch (err) ->
          alert("Ошибка при создании диаграммы: " + JSON.stringify(err))

      .catch (err) ->
        alert("Ошибка при получении projectId: " + JSON.stringify(err))

    # Добавляем кнопку входа через МГТУ
    addBmstuAuthButton = ->
      loginForm = $document[0].querySelector('.login-form')
      return unless loginForm && !loginForm.querySelector('.bmstu-auth-btn')

      separator = angular.element("""
        <div style="margin: 20px 0; position: relative; text-align: center;">
          <hr style="border: 0; border-top: 1px solid #ddd;">
          <span style="position: absolute; top: -10px; left: 50%; transform: translateX(-50%); background: white; padding: 0 10px; color: #999;">
            или
          </span>
        </div>
      """)

      button = angular.element("""
        <button class="bmstu-auth-btn"
                style="background: #005baa; color: white; padding: 10px;
                       border: none; border-radius: 4px; cursor: pointer;
                       width: 100%; font-size: 14px; margin-bottom: 20px;
                       display: flex; align-items: center; justify-content: center;
                       transition: background 0.3s;">
          <img src="/plugins/drawio/images/bmstu-logo.png"
               style="height: 20px; margin-right: 8px;"
               alt="BMSTU Logo">
          <span>Войти через МГТУ им. Н.Э. Баумана</span>
        </button>
      """)

      button.on 'click', ->
        $window.location.href = "https://science.iu5.bmstu.ru/sso/authorize?response_type=code&redirect_uri=http://localhost:9000/oauth-callback"

      angular.element(loginForm).append(separator)
      angular.element(loginForm).append(button)

    # Добавляем стили
    addStyles = ->
      style = angular.element("""
        <style>
          .bmstu-auth-btn:hover {
            background: #004a8f !important;
          }
        </style>
      """)
      angular.element($document[0].head).append(style)

    init = ->
      addStyles()
      addBmstuAuthButton()
      $timeout(checkAuthForm, 500)

    checkAuthForm = ->
      unless $document[0].querySelector('.bmstu-auth-btn')
        addBmstuAuthButton()
        $timeout(checkAuthForm, 500)

    $rootScope.$on '$viewContentLoaded', ->
      init()
      slug = getSlug()
      if slug?
        $timeout((-> fetchAttachments(slug)), 500)
]

# Добавляем обработку OAuth callback
angular.module('taigaContrib.drawio')
.run(['$location', '$window', '$http', '$timeout', ($location, $window, $http, $timeout) ->

  if $location.path() == '/oauth-callback' && $location.search().code
    $http.post('/api/v1/drawio/oauth/', {
      code: $location.search().code
      redirect_uri: 'http://localhost:9000/oauth-callback'
    }).then((response) ->
      # Сохраняем все данные как делает стандартная авторизация Taiga
      $window.localStorage.setItem('userInfo', JSON.stringify(response.data.user))
      $window.localStorage.setItem('token', response.data.auth_token)
      $window.localStorage.setItem('refresh', response.data.refresh)

      # Перенаправляем на главную с небольшой задержкой
      $timeout(() ->
        $window.location.href = '/'
      , 100)

    ).catch((error) ->
      console.error('OAuth error:', error)
      alert('Ошибка авторизации: ' + (error.data?.detail || 'Unknown error'))
      $window.location.href = '/login'
    )
])
