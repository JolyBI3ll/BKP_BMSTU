import { Component, Inject, OnInit, OnDestroy } from '@angular/core';
import { TUI_DIALOG_DATA, TuiDialogService } from '@taiga-ui/core';
import { HttpClient } from '@angular/common/http';
import { environment } from '@env';
import { AuthService } from '@taiga/services/auth.service';

@Component({
  templateUrl: './drawio-dialog.component.html',
  styleUrls: ['./drawio-dialog.component.scss']
})
export class DrawioDialogComponent implements OnInit, OnDestroy {
  iframeSrc = 'https://embed.diagrams.net/?embed=1&spin=1&proto=json&ui=min';
  private listener = this.onMessage.bind(this);

  constructor(
    @Inject(TUI_DIALOG_DATA) public att: any,
    private http: HttpClient,
    private auth: AuthService,
    private dialog: TuiDialogService
  ) {}

  ngOnInit() {
    window.addEventListener('message', this.listener);
  }
  ngOnDestroy() {
    window.removeEventListener('message', this.listener);
  }

  onLoad(iframe: HTMLIFrameElement) {
    // загрузим XML
    const url = `/api/v1/drawio/${this.att.id}/raw`;
    this.http.get<any>(url).subscribe(res => {
      iframe.contentWindow!.postMessage({
        action: 'load',
        autosave: 1,
        xml: res.xml_data
      }, '*');
    });
  }

  onMessage(evt: MessageEvent) {
    if (!evt.data || evt.data.event !== 'save') { return; }
    const xml = evt.data.xml;
    const url = `/api/v1/drawio/${this.att.id}/`;
    this.http.post(url, { xml_data: xml }).subscribe(() => {
      // закрываем диалог
      this.dialog.closeAll();
    });
  }
}