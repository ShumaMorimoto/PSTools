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

  _editAttributes(e) {
    const m = e.relatedTarget; // ← 右クリックされた Marker
    this.openEditPopup(m);
  }
  _showBoundary(e) {}
  _duplicateMarker(e) {}
  _lockMarker(e) {}
  _openInfoPanel(e) {}

  /**
   * マーカーの近くに編集用ポップアップを表示する
   * @param {L.Marker} marker 対象のマーカー
   */
  openEditPopup(marker) {
    // 現在保持しているデータを取得（なければデフォルト値）
    const currentName = marker.options.title || "";
    const currentDesc = marker.options.description || "";

    // ポップアップ内に表示するHTMLを構築
    const formHtml = `
        <div class="edit-popup-form" style="min-width: 200px; padding: 5px;">
            <strong style="display: block; margin-bottom: 8px; font-size: 14px;">拠点の詳細編集</strong>
            
            <label style="font-size: 12px; color: #666;">拠点名</label>
            <input type="text" id="pop-edit-name" value="${currentName}" 
                   style="width: 100%; margin-bottom: 10px; padding: 4px; box-sizing: border-box; border: 1px solid #ccc;">

            <label style="font-size: 12px; color: #666;">備考</label>
            <textarea id="pop-edit-desc" rows="3" 
                      style="width: 100%; margin-bottom: 10px; padding: 4px; box-sizing: border-box; border: 1px solid #ccc;">${currentDesc}</textarea>

            <div style="display: flex; justify-content: flex-end; gap: 8px;">
                <button id="pop-save-btn" style="background: #007bff; color: #fff; border: none; padding: 5px 12px; border-radius: 3px; cursor: pointer;">保存</button>
                <button id="pop-cancel-btn" style="background: #ccc; color: #333; border: none; padding: 5px 12px; border-radius: 3px; cursor: pointer;">閉じる</button>
            </div>
        </div>
    `;

    // マーカーにポップアップをセットして開く
    marker
      .bindPopup(formHtml, {
        closeButton: false, // 独自ボタンで制御するため隠す
        offset: L.point(0, -20), // 吹き出しの位置調整
      })
      .openPopup();

    // 描画後にDOM要素にイベントを紐付ける（setTimeoutで確実にDOMが作られた後に実行）
    setTimeout(() => {
      // 保存ボタン
      document.getElementById("pop-save-btn").onclick = () => {
        const newName = document.getElementById("pop-edit-name").value;
        const newDesc = document.getElementById("pop-edit-desc").value;

        // マーカー本体のデータを更新
        marker.options.title = newName;
        marker.options.description = newDesc;

        // ツールチップ（アイコン横の数字/名前）も更新
        if (marker.getTooltip()) {
          marker.setTooltipContent(`${marker.options.index}. ${newName}`);
        }

        // 【重要】左側の拠点一覧パネルも同期して更新
        if (window.pointListInstance) {
          window.pointListInstance.updateList();
        }

        marker.closePopup();
        console.log("Saved:", marker.options.title);
      };

      // キャンセルボタン
      document.getElementById("pop-cancel-btn").onclick = () => {
        marker.closePopup();
      };
    }, 10);
  }
}
