// marker-contextmenu.js

import { notify } from "./../api-utils.js";

export default class MarkerContextMenu {
  constructor(handler) {
    this.handler = handler;
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
    this.handler.removeMarker(m);
    this.handler.redraw();
  }
  _splitRoute(e) {
    const m = e.relatedTarget; // ← 右クリックされた Marker
    this.handler.removeMarker(m, true);
    this.handler.redraw();
  }
  async _setAsStart(e) {
    const m = e.relatedTarget; // ← 右クリックされた Marker
    this.handler.jumpMarker(m);
    await this.handler.reorderMarkers();
    this.handler.redraw();
  }

  _addAsWaypoint(e) {}

  async _updateAddress(e) {
    const m = e.relatedTarget; // ← 右クリックされた Marker
    const entry = this.handler.getEntry(m);
    const point = entry.point;
    await this.handler.address.updateAddress(point);
  }

  _editAttributes(e) {
    const m = e.relatedTarget; // ← 右クリックされた Marker
    this.createPopupTemplate(m);
  }
  _showBoundary(e) {}
  _duplicateMarker(e) {}
  _lockMarker(e) {}
  _openInfoPanel(e) {}

  // --- 内部アクション ---

  _editAttributes(e) {
    const m = e.relatedTarget;
    const entry = this.handler.getEntry(m);
    if (!entry) return;

    const point = entry.point;

    // 1. ページ（DOM）の生成
    const $page = this._createPopupTemplate(point);

    // 2. アクションの紐付け
    this._bindPageAction($page, m, point, (newData) => {
      // 保存時のコールバック: データの更新
      point.name = newData.name;
      point.description = newData.desc;
      if (!point.extensions) point.extensions = {};
      point.extensions.keyword = newData.keyword;

      // マーカーの表示更新
      m.options.title = point.name;
      if (m.getTooltip()) {
        m.setTooltipContent(`${m.options.index || ""}. ${point.name}`);
      }

      // 一覧パネル等の外部更新
      if (window.pointListInstance) {
        window.pointListInstance.updateList();
      }

      notify("✅ 保存しました");
    });

    // 3. Leafletポップアップとして表示
    m.bindPopup($page, { minWidth: 220, closeButton: false }).openPopup();
  }

  // --- テンプレート・表示制御ロジック ---

  _createPopupTemplate(point) {
    const { lat, lon, name, desc, extensions = {} } = point;
    const { keyword = "", ...others } = extensions;

    const div = document.createElement("div");
    div.className = "popup-container";
    div.setAttribute("data-mode", "show");

    // extensionsのループ：キーの幅を揃えるレイアウト
    const extensionsHtml = Object.entries(others)
      .map(
        ([k, v]) => `
      <div class="ext-row">
        <span class="ext-key">${k}:</span>
        <span class="ext-val">${v}</span>
      </div>
    `
      )
      .join("");

    div.innerHTML = `
    <div class="popup-body">
      <div class="popup-field">
        <label>座標</label>
        <div class="val" style="color:#aaa">${lat.toFixed(6)}, ${lon.toFixed(
      6
    )}</div>
      </div>

      <div class="popup-field">
        <label>名称</label>
        <div class="view-mode val">${name || "---"}</div>
        <input type="text" class="edit-mode" name="name" value="${name || ""}">
      </div>

      <div class="popup-field">
        <label>備考</label>
        <div class="view-mode val">${desc || "---"}</div>
        <textarea class="edit-mode" name="desc" rows="2">${
          desc || ""
        }</textarea>
      </div>

      <div class="popup-field">
        <label>キーワード</label>
        <div class="view-mode val"><code>${keyword || "---"}</code></div>
        <input type="text" class="edit-mode" name="keyword" value="${
          keyword || ""
        }">
      </div>

      <div class="extensions-list">
        <label>拡張属性</label>
        ${
          extensionsHtml ||
          '<div style="color:#ccc; font-size:10px;">なし</div>'
        }
      </div>
    </div>

    <div class="popup-actions">
      <button class="btn-update view-mode">更新</button>
      <button class="btn-edit view-mode">編集</button>
      <button class="btn-close view-mode">戻る</button>

      <button class="btn-save edit-mode">保存</button>
      <button class="btn-cancel edit-mode">戻る</button>
    </div>
  `;
    return div;
  }

  _bindPageAction($page, marker, point, onSave) {
    // 更新ボタンのアクション
    $page.querySelector(".btn-update").onclick = async () => {
      const btn = $page.querySelector(".btn-update");
      const listContainer = $page.querySelector(".extensions-list");

      // 1. ローディング状態の表示
      const originalText = btn.textContent;
      btn.textContent = "更新中...";
      btn.disabled = true;
      listContainer.style.opacity = "0.5";

      try {
        // 2. 住所情報の取得（api-utilsの関数を想定）
        // point.lat, point.lon を元に最新データを取得
        // const newData = await this.handler.address.fetchAddressAsync({
        //   lat: point.lat,
        //   lon: point.lon,
        // });

        if (newData && newData.address) {
          // pointオブジェクトのextensionsを最新に更新
          point.extensions = { ...point.extensions, ...newData.address };

          // 3. 画面上の拡張属性リストだけを書き換える
          const { keyword, ...others } = point.extensions;
          const newExtensionsHtml = Object.entries(others)
            .map(
              ([k, v]) => `
            <div class="ext-row">
              <span class="ext-key">${k}:</span>
              <span class="ext-val">${v}</span>
            </div>
          `
            )
            .join("");

          listContainer.innerHTML = `<label>拡張属性</label>${newExtensionsHtml}`;

          // 備考欄なども必要に応じて更新（例：住所文字列を備考に入れる場合）
          // $page.querySelector('.view-mode.val').textContent = point.name;

          notify("🏠 住所情報を更新しました");
        }
      } catch (error) {
        console.error(error);
        notify("❌ 更新に失敗しました");
      } finally {
        // 4. 状態を元に戻す
        btn.textContent = originalText;
        btn.disabled = false;
        listContainer.style.opacity = "1";
      }
    };

    // 編集モードへ
    $page.querySelector(".btn-edit").onclick = () => {
      $page.setAttribute("data-mode", "editable");
    };

    // 戻る/閉じる（表示モード時）
    $page.querySelector(".btn-close").onclick = () => {
      marker.closePopup();
    };

    // 戻る/キャンセル（編集モード時）
    $page.querySelector(".btn-cancel").onclick = () => {
      $page.setAttribute("data-mode", "show");
    };

    // 保存
    $page.querySelector(".btn-save").onclick = () => {
      const newData = {
        name: $page.querySelector('[name="name"]').value,
        desc: $page.querySelector('[name="desc"]').value,
        keyword: $page.querySelector('[name="keyword"]').value,
      };
      onSave(newData);
      marker.closePopup();
    };
  }
}
