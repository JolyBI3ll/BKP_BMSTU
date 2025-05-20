import { NgModule } from '@angular/core';
import { CommonModule } from '@angular/common';
import { TaigaUIIconModule } from '@taiga-ui/core';
import { AttachmentDrawioBtnComponent } from './attachment-drawio-btn.component';

@NgModule({
  declarations: [AttachmentDrawioBtnComponent],
  imports: [CommonModule, TaigaUIIconModule],
  exports: [AttachmentDrawioBtnComponent]
})
export class DrawioModule {}