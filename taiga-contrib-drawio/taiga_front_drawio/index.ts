import { TaigaApp } from '@taiga-ui/core';
import { DrawioModule } from './drawio.module';

export function activate(app: TaigaApp) {
  app.attachments.registerExtraAction(DrawioModule);
}