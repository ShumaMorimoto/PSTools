L.Control.PointListPanel = L.Control.extend({
  options: {
    position: "topleft", // 実際にはCSSで固定位置を制御
    getPoints: null,
    onSelect: null,
  },

  // 初期化時にオプションを確実にセット
  initialize: function (options) {
    L.setOptions(this, options);
  },

  onAdd: function (map) {
    this._map = map;

    // 1. パネル本体を作成し、インスタンス変数 this._panel に保存する
    this._panel = L.DomUtil.create(
      "div",
      "leaflet-side-panel",
      map.getContainer()
    );

    this._panel.innerHTML = `
    <div class="panel-header">
        <span>拠点一覧</span>
        <span class="close-btn" style="cursor:pointer; font-size:20px;">&times;</span>
    </div>
    <div class="panel-content"> <ul class="point-list-ul"></ul>
    </div>
`;

    L.DomEvent.disableClickPropagation(this._panel);
    L.DomEvent.disableScrollPropagation(this._panel);

    const closeBtn = this._panel.querySelector(".close-btn");
    L.DomEvent.on(closeBtn, "click", () => this.toggle(false));

    // 2. Leafletの管理システムに返すのはダミーで良いが、これは this._container になる
    return L.DomUtil.create("div", "hidden-dummy-control");
  },

  toggle: function (force) {
    // 3. 操作対象を this._container ではなく this._panel に変更する
    if (!this._panel) return false;

    const isOpen =
      force !== undefined ? force : !this._panel.classList.contains("open");

    if (isOpen) {
      this._panel.classList.add("open");
    } else {
      this._panel.classList.remove("open");
    }

    return isOpen;
  },

  updateList: function () {
    // 4. updateList 内の参照も this._panel に変更
    if (!this._panel) return;
    const ul = this._panel.querySelector(".point-list-ul");
    if (!ul) return;

    ul.innerHTML = "";

    if (typeof this.options.getPoints !== "function") return;

    const pts = this.options.getPoints();
    if (!pts || !Array.isArray(pts)) return;

    pts.forEach((p, i) => {
      const li = L.DomUtil.create("li", "point-list-item", ul);

      // 座標のプロパティ名（lon / lng）の両方に対応
      const lat = p.lat !== undefined ? p.lat : "?";
      const lng =
        p.lon !== undefined ? p.lon : p.lng !== undefined ? p.lng : "?";
      const coordStr =
        lat !== "?" && lng !== "?"
          ? `${lat.toFixed(4)}, ${lng.toFixed(4)}`
          : "座標なし";

      li.innerHTML = `<strong>${i + 1}.</strong> ${
        p.name || p.desc || coordStr
      }`;

      L.DomEvent.on(li, "click", (e) => {
        L.DomEvent.stopPropagation(e); // 地図へのクリック伝播を防止
        if (typeof this.options.onSelect === "function") {
          this.options.onSelect(i);
        }
      });
    });
  },
});

L.control.pointListPanel = (opts) => new L.Control.PointListPanel(opts);
