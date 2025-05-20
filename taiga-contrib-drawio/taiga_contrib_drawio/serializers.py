from taiga.base.api import serializers
from taiga.base.fields import Field
from .models import DrawioAttachment


class DrawioAttachmentSerializer(serializers.LightSerializer):
    id = Field()
    attachment_id = Field()   # FK id
    xml_data = Field()
    created = Field()
    modified = Field()

    class Meta:
        model = DrawioAttachment
        fields = ("id", "attachment_id", "xml_data", "created", "modified")