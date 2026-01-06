// marker-contextmenu.js

import { notify } from "./../api-utils.js";

export default class MarkerContextMenu {
  constructor(handler, core) {
    this.handler = handler;
    this.core = core;
  }

  bindContextMenu(m) {
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
        { text: "🏠 住所更新", callback: (e) => this._updateAddress(e) },
        { text: "✏️ 属性編集", callback: (e) => this._editAttributes(e) },
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
    this.core.removeMarker(m);
    this.handler.redraw();
  }
  _splitRoute(e) {
    const m = e.relatedTarget; // ← 右クリックされた Marker
    this.core.removeMarker(m, true);
    this.handler.redraw();
  }
  async _setAsStart(e) {
    const m = e.relatedTarget; // ← 右クリックされた Marker
    this.core.jumpMarker(m);
    await this.core.reorderByTSP();
    this.handler.redraw();
  }

  _addAsWaypoint(e) {}

  async _updateAddress(e) {
    const m = e.relatedTarget; // ← 右クリックされた Marker
    const entry = this.core.markers.find((x) => x.m === m);
    const point = entry.point;
    await this.handler.address.updateAddress(point);
  }

  _editAttributes(e) {}
  _showBoundary(e) {}
  _duplicateMarker(e) {}
  _lockMarker(e) {}
  _openInfoPanel(e) {}
}
