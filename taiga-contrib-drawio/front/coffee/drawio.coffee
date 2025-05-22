angular.module('taigaContrib.drawio', [])
.run [
  '$http', '$timeout', '$compile', '$document', '$window', '$rootScope'
  ($http, $timeout, $compile, $document, $window, $rootScope) ->

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
      btn = angular.element("<button class='drawio-btn' style='margin-left: 10px; background: #83eede; color: #000; border: none; border-radius: 4px; cursor: pointer; transition: background 0.3s ease;'>Редактировать в Draw.io</button>")

      btn.on 'mouseenter', -> btn.css('background', '#008aa8')
      btn.on 'mouseleave', -> btn.css('background', '#83eede')
      btn.on 'click', -> openDrawioEditor(attachmentId)

      angular.element(link).after(btn)

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


    $rootScope.$on '$viewContentLoaded', ->
      slug = getSlug()
      if slug?
        $timeout((-> fetchAttachments(slug)), 500)
]
