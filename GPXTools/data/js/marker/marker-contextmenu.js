// marker-contextmenu.js

import { notify } from "./../api-utils.js";

export default class MarkerContextMenu {
  constructor(handler) {
    this.handler = handler;
  }

  bindMarker(m) {
    if (m._contextMenuBound) return;
    m.unbindContextMenu();

    const { lat, lng } = m.getLatLng();

    m.bindContextMenu({
      contextmenu: true,
      contextmenuItems: [
        {
          text: `📌 ${lat.toFixed(5)}, ${lng.toFixed(5)}`,
          callback: (e) => this._copyLatLng(e),
        },
        { text: "🗑 マーカー削除", callback: (e) => this._deleteMarker(e) },
        { text: "✂ ルート分割", callback: (e) => this._splitRoute(e) },
        { text: "🚩 始点設定", callback: (e) => this._setAsStart(e) },
        { text: "🗺 境界表示", callback: (e) => this._showBoundary(e) },
      ],
    });

    m._contextMenuBound = true;
  }

  _copyLatLng(e) {
    const m = e.relatedTarget; // 右クリックされた Marker
    const { lat, lng } = m.getLatLng();
    const text = `${lat},${lng}`;

    navigator.clipboard
      .writeText(text)
      .then(() => {
        notify("📋 座標をコピーしました");
      })
      .catch((err) => {
        console.error("Clipboard copy failed:", err);
      });
  }

  _deleteMarker(e) {
    const m = e.relatedTarget; // ← 右クリックされた Marker
    this.handler.removeMarker(m);
  }
  _splitRoute(e) {
    const m = e.relatedTarget; // ← 右クリックされた Marker
    this.handler.removeMarker(m, true);
  }
  async _setAsStart(e) {
    const m = e.relatedTarget; // ← 右クリックされた Marker
    this.handler.jumpMarker(m);
    await this.handler.reorderMarkers();
  }

  _showBoundary(e) {}
  _duplicateMarker(e) {}
  _lockMarker(e) {}
  _openInfoPanel(e) {}

}
