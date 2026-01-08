L.Control.PointListPanel = L.Control.extend({
  options: {
    position: "topleft",
    getPoints: null,
    onSelect: null,
    onDelete: null, // ★ 削除時のコールバックを追加
  },

  initialize: function (options) {
    L.setOptions(this, options);
  },

  onAdd: function (map) {
    this._map = map;
    this._panel = L.DomUtil.create("div", "leaflet-side-panel", map.getContainer());

    this._panel.innerHTML = `
      <div class="panel-header">
          <span>拠点一覧</span>
          <span class="close-btn" style="cursor:pointer; font-size:20px;">&times;</span>
      </div>
      <div class="panel-content">
          <ul class="point-list-ul"></ul>
      </div>
    `;

    L.DomEvent.disableClickPropagation(this._panel);
    L.DomEvent.disableScrollPropagation(this._panel);

    const closeBtn = this._panel.querySelector(".close-btn");
    L.DomEvent.on(closeBtn, "click", () => this.toggle(false));

    return L.DomUtil.create("div", "hidden-dummy-control");
  },

  toggle: function (force) {
    if (!this._panel) return false;
    const isOpen = force !== undefined ? force : !this._panel.classList.contains("open");
    if (isOpen) {
      this._panel.classList.add("open");
    } else {
      this._panel.classList.remove("open");
    }
    return isOpen;
  },

  updateList: function () {
    if (!this._panel) return;
    const ul = this._panel.querySelector(".point-list-ul");
    if (!ul) return;

    ul.innerHTML = "";
    if (typeof this.options.getPoints !== "function") return;

    const pts = this.options.getPoints();
    if (!pts || !Array.isArray(pts)) return;

    pts.forEach((p, i) => {
      const li = L.DomUtil.create("li", "point-list-item", ul);
      // ★ スタイル調整用：Flexboxで横並びにする
      li.style.display = "flex";
      li.style.justifyContent = "space-between";
      li.style.alignItems = "center";

      const lat = p.lat !== undefined ? p.lat : "?";
      const lng = p.lon !== undefined ? p.lon : p.lng !== undefined ? p.lng : "?";
      const coordStr = lat !== "?" && lng !== "?" ? `${lat.toFixed(4)}, ${lng.toFixed(4)}` : "座標なし";

      // ★ テキスト部分と削除ボタンを分ける
      li.innerHTML = `
        <div class="item-main" style="flex-grow: 1; cursor: pointer;">
          <strong>${i + 1}.</strong> ${p.name || p.desc || coordStr}
        </div>
        <span class="item-delete-btn" style="cursor:pointer; padding: 0 5px; color: #999; font-size: 18px;">&times;</span>
      `;

      // メイン部分（選択）
      const mainPart = li.querySelector(".item-main");
      L.DomEvent.on(mainPart, "click", (e) => {
        L.DomEvent.stopPropagation(e);
        if (typeof this.options.onSelect === "function") {
          this.options.onSelect(i);
        }
      });

      // ★ 削除ボタン
      const delBtn = li.querySelector(".item-delete-btn");
      L.DomEvent.on(delBtn, "click", (e) => {
        L.DomEvent.stopPropagation(e);
        if (confirm("この拠点を削除しますか？")) {
          if (typeof this.options.onDelete === "function") {
            this.options.onDelete(i);
          }
        }
      });
      
      // ホバー時に×ボタンを目立たせる
      L.DomEvent.on(delBtn, "mouseover", () => { delBtn.style.color = "#f00"; });
      L.DomEvent.on(delBtn, "mouseout", () => { delBtn.style.color = "#999"; });
    });
  },
});

L.control.pointListPanel = (opts) => new L.Control.PointListPanel(opts);