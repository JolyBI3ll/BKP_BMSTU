import { Injectable, Injector } from '@angular/core';
import { TuiDialogService } from '@taiga-ui/core';
import { DrawioDialogComponent } from './drawio-dialog.component';
import { HttpClient } from '@angular/common/http';
import { AuthService } from '@taiga/services/auth.service';

@Injectable({ providedIn: 'root' })
export class DrawioService {
  constructor(
    private dialog: TuiDialogService,
    private injector: Injector,
  ) {}

  openEditor(att: any) {
    this.dialog.open(DrawioDialogComponent, {
      data: att,
      label: `Draw.io – ${att.filename}`,
      size: 'fullscreen',
      dismissible: false
    }).subscribe();
  }
}