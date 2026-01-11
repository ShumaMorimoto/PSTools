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
      map.getContainer()
    );

    // --- スタイル調整 ---
    Object.assign(this._panel.style, {
      position: "absolute",
      left: "70px", // ★ ツールバーからさらに離して 70px に設定
      top: "10px",
      width: "300px",
      backgroundColor: "white",
      boxShadow: "0 2px 10px rgba(0,0,0,0.3)",
      zIndex: "1000",
      display: "none",
      flexDirection: "column",
      borderRadius: "8px", // 少し角を丸くしてモダンに
      border: "1px solid #ccc",
      overflow: "hidden",
    });

    this._panel.innerHTML = `
      <div class="panel-header" style="
        display: flex; 
        justify-content: space-between; 
        align-items: center; 
        padding: 12px 15px; 
        background: #fdfdfd; 
        border-bottom: 2px solid #eee;
        user-select: none;
      ">
          <span style="font-weight: bold; font-size: 17px; color: #333;">拠点一覧</span>
          <span class="close-btn" style="
            cursor: pointer; 
            font-size: 22px; 
            font-weight: bold;
            line-height: 1; 
            color: #888; 
            padding: 5px 10px;
            margin-left: 20px; /* タイトルとしっかり離す */
            border-radius: 50%;
            transition: all 0.2s;
            display: inline-block;
          ">&times;</span>
      </div>
      <div class="panel-content" style="max-height: 75vh; overflow-y: auto;">
          <ul class="point-list-ul" style="list-style: none; margin: 0; padding: 0;"></ul>
      </div>
    `;

    L.DomEvent.disableClickPropagation(this._panel);
    L.DomEvent.disableScrollPropagation(this._panel);

    const closeBtn = this._panel.querySelector(".close-btn");
    // 閉じるボタンのホバー演出を強化
    L.DomEvent.on(closeBtn, "mouseover", () => {
      closeBtn.style.backgroundColor = "#ff4d4f";
      closeBtn.style.color = "#fff";
    });
    L.DomEvent.on(closeBtn, "mouseout", () => {
      closeBtn.style.backgroundColor = "transparent";
      closeBtn.style.color = "#888";
    });
    L.DomEvent.on(closeBtn, "click", () => this.toggle(false));

    return L.DomUtil.create("div", "hidden-dummy-control");
  },
  
  toggle: function (force) {
    if (!this._panel) return false;
    const isOpen =
      force !== undefined ? force : this._panel.style.display === "none";

    if (isOpen) {
      this._panel.style.display = "flex";
      this._panel.classList.add("open"); // CSSアニメーション用
    } else {
      this._panel.style.display = "none";
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
      Object.assign(li.style, {
        display: "flex",
        justifyContent: "space-between",
        alignItems: "center",
        padding: "8px 15px",
        borderBottom: "1px solid #eee",
        transition: "background 0.1s",
      });

      const lat = p.lat !== undefined ? p.lat : "?";
      const lng =
        p.lon !== undefined ? p.lon : p.lng !== undefined ? p.lng : "?";
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
        <span class="item-delete-btn" style="
          cursor: pointer; 
          padding: 4px 8px; 
          color: #ccc; 
          font-size: 20px; 
          line-height: 1;
        ">&times;</span>
      `;

      // リスト項目のホバー
      L.DomEvent.on(li, "mouseover", () => {
        li.style.backgroundColor = "#fcfcfc";
      });
      L.DomEvent.on(li, "mouseout", () => {
        li.style.backgroundColor = "transparent";
      });

      const mainPart = li.querySelector(".item-main");
      L.DomEvent.on(mainPart, "click", (e) => {
        L.DomEvent.stopPropagation(e);
        if (typeof this.options.onSelect === "function") {
          this.options.onSelect(i);
        }
      });

      const delBtn = li.querySelector(".item-delete-btn");
      L.DomEvent.on(delBtn, "click", (e) => {
        L.DomEvent.stopPropagation(e);
        if (confirm("この拠点を削除しますか？")) {
          if (typeof this.options.onDelete === "function") {
            this.options.onDelete(i);
          }
        }
      });

      L.DomEvent.on(delBtn, "mouseover", () => {
        delBtn.style.color = "#dc3545";
      });
      L.DomEvent.on(delBtn, "mouseout", () => {
        delBtn.style.color = "#ccc";
      });
    });
  },
});

L.control.pointListPanel = (opts) => new L.Control.PointListPanel(opts);
