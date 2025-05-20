import { Component, Input } from '@angular/core';
import { Attachment } from '@taiga/models';
import { DrawioService } from './drawio.service';

@Component({
  selector: 'drawio-edit-btn',
  templateUrl: './attachment-drawio-btn.component.html',
})
export class AttachmentDrawioBtnComponent {
  @Input() attachment!: Attachment;           // приходит из core

  constructor(private drawio: DrawioService) {}

  canShow(): boolean {
    return this.attachment.filename.endsWith('.drawio');
  }
  click() {
    this.drawio.openEditor(this.attachment);
  }
}