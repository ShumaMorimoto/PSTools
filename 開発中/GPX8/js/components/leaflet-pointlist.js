// components/leaflet-pointlist.js

// initializerから呼べるように「export」を付ける
export function initPointListPanel() {
  // 二重定義防止
  if (L.Control.PointListPanel) return;

  L.Control.PointListPanel = L.Control.extend({
    options: {
      position: "topleft",
      getPoints: null,
      onSelect: null,
      onDelete: null,
    },

    initialize: function (options) {
      L.setOptions(this, options);
    },

    onAdd: function (map) {
      this._map = map;
      this._panel = L.DomUtil.create(
        "div",
        "leaflet-side-panel",
        map.getContainer(),
      );

      // --- 再適用：ボタンとかぶらないための補正 ---
      Object.assign(this._panel.style, {
        left: "70px", // ★ ボタン群の右隣に配置
        top: "10px", // ★ 上下に少し隙間を作る
        height: "calc(100% - 20px)",
        zIndex: "3000",
        pointerEvents: "auto",
        display: "flex", // CSSの display:none と競合しないよう flex で固定
      });

      this._panel.innerHTML = `
    <div class="panel-header" style="display: flex; justify-content: space-between; align-items: center; padding: 12px 15px; background: #fdfdfd; border-bottom: 2px solid #eee; user-select: none;">
        <span style="font-weight: bold; font-size: 17px; color: #333;">拠点一覧</span>
        <span class="close-btn" style="cursor: pointer; font-size: 24px; font-weight: bold; color: #888; padding: 0 10px; line-height: 1;">&times;</span>
    </div>
    <div class="panel-content" style="flex: 1; overflow-y: auto;">
        <ul class="point-list-ul" style="list-style: none; margin: 0; padding: 0;"></ul>
    </div>
  `;

      L.DomEvent.disableClickPropagation(this._panel);
      L.DomEvent.disableScrollPropagation(this._panel);

      const closeBtn = this._panel.querySelector(".close-btn");
      L.DomEvent.on(closeBtn, "click", () => this.toggle(false));

      return L.DomUtil.create("div", "hidden-dummy-control");
    },

    // 開閉状態を返す（Initializerで使用）
    // leaflet-pointlist.js 内

    isOpen: function () {
      // style.display ではなく、クラスを持っているかで判定
      return this._panel && this._panel.classList.contains("open");
    },

    toggle: function (force) {
      if (!this._panel) return false;

      // forceが指定されていればその通りに、なければ反転
      const shouldOpen = force !== undefined ? force : !this.isOpen();

      if (shouldOpen) {
        this._panel.classList.add("open");
        this.updateList();
      } else {
        this._panel.classList.remove("open");
      }

      return shouldOpen;
    },

    updateList: function () {
      if (!this._panel) return;
      const ul = this._panel.querySelector(".point-list-ul");
      if (!ul || typeof this.options.getPoints !== "function") return;

      ul.innerHTML = "";
      const pts = this.options.getPoints();
      if (!pts || !Array.isArray(pts)) return;

      pts.forEach((p, i) => {
        const li = L.DomUtil.create("li", "point-list-item", ul);
        Object.assign(li.style, {
          display: "flex",
          justifyContent: "space-between",
          alignItems: "center",
          padding: "8px 15px",
          borderBottom: "1px solid #eee",
          transition: "background 0.1s",
        });

        const lat = p.lat ?? "?";
        const lng = p.lon ?? p.lng ?? "?";
        const coordStr =
          lat !== "?" && lng !== "?"
            ? `${lat.toFixed(4)}, ${lng.toFixed(4)}`
            : "座標なし";

        li.innerHTML = `
          <div class="item-main" style="flex-grow: 1; cursor: pointer; padding-right: 10px;">
            <strong style="color: #007bff;">${i + 1}.</strong> ${
              p.name || p.desc || coordStr
            }
          </div>
          <span class="item-delete-btn" style="cursor: pointer; padding: 4px 8px; color: #ccc; font-size: 20px; line-height: 1;">&times;</span>
        `;

        // メイン部分クリック（ズーム）
        L.DomEvent.on(li.querySelector(".item-main"), "click", (e) => {
          L.DomEvent.stopPropagation(e);
          this.options.onSelect?.(i);
        });

        // 削除ボタン
        const delBtn = li.querySelector(".item-delete-btn");
        L.DomEvent.on(delBtn, "click", (e) => {
          L.DomEvent.stopPropagation(e);
          this.options.onDelete?.(i);
        });
      });
    },
  });

  L.control.pointListPanel = (opts) => new L.Control.PointListPanel(opts);
}
