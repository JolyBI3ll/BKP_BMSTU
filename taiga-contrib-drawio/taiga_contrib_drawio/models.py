from django.db import models
from taiga.projects.attachments.models import Attachment

class DrawioAttachment(models.Model):
    attachment = models.OneToOneField(
        Attachment,
        on_delete=models.CASCADE,
        related_name="drawio_meta",
    )
    # будем хранить оригинальную XML-структуру диаграммы
    xml_data = models.TextField(blank=True, default="")

    created = models.DateTimeField(auto_now_add=True)
    modified = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "drawio_attachment"

    def __str__(self):
        return f"DrawioAttachment<{self.attachment_id}>"