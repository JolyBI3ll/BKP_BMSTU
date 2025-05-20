from django.utils.translation import gettext as _
from taiga.base import exceptions as exc
from taiga.base import response
from taiga.base.api import viewsets
#from taiga.base.decorators import list_route
from taiga.projects.attachments.models import Attachment
from django.http import Http404
from .models import DrawioAttachment
from .serializers import DrawioAttachmentSerializer
#from taiga.base.decorators import detail_route


class DrawioViewSet(viewsets.ViewSet):
    """
    • GET  /api/v1/drawio/<attachment_id>/      – получить XML
    • POST /api/v1/drawio/<attachment_id>/      – записать/обновить XML
    • GET  /api/v1/drawio/<attachment_id>/raw   – чистый XML
    • DELETE /api/v1/drawio/<attachment_id>/reset – очистить
    """

    serializer_class = DrawioAttachmentSerializer
    permission_classes = tuple()

    # ---- internal helpers ------------------------------------------------
    def _get_obj(self, attachment_id, request):
        try:
            att = Attachment.objects.get(id=attachment_id)
        except Attachment.DoesNotExist:
            raise Http404

        self.check_object_permissions(request, att)

        obj, _ = DrawioAttachment.objects.get_or_create(attachment=att)
        return obj

    # ---- базовые методы --------------------------------------------------
    def retrieve(self, request, attachment_id=None, **kwargs):
        draw = self._get_obj(attachment_id, request)
        data = self.serializer_class(draw).data
        return response.Ok(data)

    def create(self, request, attachment_id=None, **kwargs):
        draw = self._get_obj(attachment_id, request)
        xml = request.DATA.get("xml_data")
        if xml is None:
            raise exc.BadRequest(_("`xml_data` field is required"))

        draw.xml_data = xml
        draw.save(update_fields=("xml_data", "modified"))
        return response.Ok(self.serializer_class(draw).data)

    # ---- дополнительные маршруты ----------------------------------------
    def raw(self, request, attachment_id=None, **kwargs):
        draw = self._get_obj(attachment_id, request)
        return response.Ok({"xml_data": draw.xml_data})

    def reset(self, request, attachment_id=None, **kwargs):
        draw = self._get_obj(attachment_id, request)
        draw.xml_data = ""
        draw.save(update_fields=("xml_data", "modified"))
        return response.NoContent()