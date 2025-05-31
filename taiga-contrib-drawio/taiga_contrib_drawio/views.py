import logging
import os
import uuid
import re
import requests
from django.core.cache import cache
from django.http import Http404
from django.utils.translation import gettext as _
from taiga.base import exceptions as exc
from taiga.base import response
from taiga.base.api import viewsets
from taiga.projects.attachments.models import Attachment
from .models import DrawioAttachment
from .serializers import DrawioAttachmentSerializer

logger = logging.getLogger(__name__)

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

    def _get_gigachat_token(self):
        cached_token = cache.get("gigachat_access_token")
        if cached_token:
            return cached_token

        try:
            auth_key = os.getenv('GIGACHAT_AUTH_KEY')
            if not auth_key:
                raise ValueError("GIGACHAT_AUTH_KEY in environment")

            auth_url = "https://ngw.devices.sberbank.ru:9443/api/v2/oauth"
            headers = {
                'Content-Type': 'application/x-www-form-urlencoded',
                'Accept': 'application/json',
                'RqUID': str(uuid.uuid4()),
                'Authorization': f'Basic {auth_key}'
            }

            response = requests.post(
                auth_url,
                headers=headers,
                data={'scope': 'GIGACHAT_API_PERS'},
                verify=True
            )
            response.raise_for_status()

            token_data = response.json()
            access_token = token_data.get('access_token')
            expires_in = token_data.get('expires_in', 1800)  # 30 минут по умолчанию

            if not access_token:
                raise exc.BadRequest(_("GigaChat: No access_token in response"))

            cache.set("gigachat_access_token", access_token, timeout=expires_in - 60)
            return access_token

        except requests.RequestException as e:
            raise exc.BadRequest(_(f"GigaChat auth error: {str(e)}"))

    def _generate_drawio_xml(self, prompt: str) -> str:
        """
        Генерирует Draw.io XML напрямую через GigaChat API
        """
        max_retries = 2
        attempt = 0

        while attempt < max_retries:
            try:
                logger.info(f"Generating Drawio XML (attempt {attempt + 1})")

                access_token = self._get_gigachat_token()
                api_url = "https://gigachat.devices.sberbank.ru/api/v1/chat/completions"

                headers = {
                    'Authorization': f'Bearer {access_token}',
                    'Content-Type': 'application/json'
                }

                chat_prompt = (
                    f"Сгенерируй XML-код для Draw.io по описанию:\n{prompt}\n\n"
                    f"Требования:\n"
                    f"- Только валидный XML код без ``` и пояснений\n"
                    f"- Используй стандартную структуру Draw.io XML\n"
                    f"- Перепроверяй себя на наличие ошибок и соблюдение синтаксиса xml валидный для drawio\n"
                    f"- Пример формата:\n"
                    f"<mxfile>\n"
                    f"  <diagram name=\"Page-1\" id=\"...\">\n"
                    f"    <mxGraphModel>\n"
                    f"      <root>\n"
                    f"        <mxCell id=\"0\"/>\n"
                    f"        <mxCell id=\"1\" parent=\"0\"/>\n"
                    f"        <mxCell id=\"2\" value=\"Элемент\" .../>\n"
                    f"      </root>\n"
                    f"    </mxGraphModel>\n"
                    f"  </diagram>\n"
                    f"</mxfile>"
                )

                response = requests.post(
                    api_url,
                    headers=headers,
                    json={
                        "model": "GigaChat-2-Max",
                        "messages": [{"role": "user", "content": chat_prompt}],
                    },
                )

                if response.status_code == 401 and attempt == 0:
                    logger.warning("Invalid token, retrying...")
                    cache.delete("gigachat_access_token")
                    attempt += 1
                    continue

                response.raise_for_status()
                result = response.json()
                raw_xml = result["choices"][0]["message"]["content"]

                # Очистка XML и извлечение только содержимого между <mxfile> и </mxfile>
                clean_xml = raw_xml.replace('```xml', '').replace('```', '').strip()

                # Ищем полную структуру mxfile
                mxfile_match = re.search(r'<mxfile.*?</mxfile>', clean_xml, re.DOTALL)
                if mxfile_match:
                    clean_xml = mxfile_match.group(0)

                    # Убедимся, что есть закрывающий тег
                    if not clean_xml.endswith('</mxfile>'):
                        # Если нет, добавим его
                        clean_xml = clean_xml.split('<mxfile')[1]
                        clean_xml = f'<mxfile{clean_xml}</mxfile>'

                    return clean_xml
                else:
                    # Если не нашли полную структуру, попробуем собрать вручную
                    if '<mxfile' in clean_xml:
                        parts = clean_xml.split('<mxfile')
                        if len(parts) > 1:
                            xml_content = parts[1]
                            if '</mxfile>' not in xml_content:
                                xml_content = xml_content.split('>', 1)[1]
                                return f'<mxfile>{xml_content}</mxfile>'
                    raise ValueError("No valid mxfile XML structure found in response")

            except requests.RequestException as e:
                logger.error(f"GigaChat API error: {str(e)}")
                if attempt == max_retries - 1:
                    raise exc.BadRequest(_("Failed to generate Drawio XML"))
                attempt += 1
            except Exception as e:
                logger.error(f"XML processing error: {str(e)}")
                if attempt == max_retries - 1:
                    raise exc.BadRequest(_("Failed to process generated XML"))
                attempt += 1

    def generate_from_prompt(self, request, attachment_id=None, **kwargs):
        """Генерация и сохранение Draw.io XML"""
        try:
            logger.info(f"Starting generation for attachment {attachment_id}")

            # Валидация промпта
            prompt = request.DATA.get("prompt")
            if not prompt or len(prompt.strip()) < 10:
                raise exc.BadRequest(_("Description must be at least 10 characters"))
            if len(prompt) > 1000:
                raise exc.BadRequest(_("Description is too long"))

            # Генерация Draw.io XML
            try:
                xml = self._generate_drawio_xml(prompt)
                logger.debug(f"Generated XML (first 200 chars): {xml[:200]}...")
            except Exception as e:
                logger.error(f"XML generation failed: {str(e)}")
                raise exc.BadRequest(_("Failed to generate diagram. Please try another description."))

            # Сохранение
            draw = self._get_obj(attachment_id, request)
            draw.xml_data = xml
            draw.save(update_fields=("xml_data", "modified"))

            return response.Ok(self.serializer_class(draw).data)

        except exc.BadRequest:
            raise
        except Exception as e:
            logger.exception("Unexpected error in diagram generation")
            raise exc.BadRequest(_("Unexpected error. Please contact support."))