// --------------------------------------------------------------------------
// L.Control.ButtonGroup 定義
// --------------------------------------------------------------------------
L.Control.ButtonGroup = L.Control.extend({
  options: { position: "topleft", buttons: [] },

  onAdd: function (map) {
    const container = L.DomUtil.create("div", "leaflet-control leaflet-bar");
    L.DomEvent.disableClickPropagation(container);

    this._map = map;
    this._btnElems = {};
    this._fileElems = {};

    container.innerHTML = this.options.buttons
      .map(
        (btn) => `
        <a href="#" id="${btn.id}" class="btn status-default" title="${
          btn.title || ""
        }">
          ${btn.icon}
        </a>
        ${
          btn.fileInput
            ? `<input type="file" id="${btn.id}_file" accept="${
                btn.accept || ""
              }" style="display:none;">`
            : ""
        }
      `
      )
      .join("");

    this.options.buttons.forEach((btn) => {
      this._btnElems[btn.id] = container.querySelector(`#${btn.id}`);
      if (btn.fileInput)
        this._fileElems[btn.id] = container.querySelector(`#${btn.id}_file`);
    });

    return container;
  },

  // ★ 汎用ハンドラ設定メソッド
  setButtonHandler: function (btnId, handlers) {
    const btn = this._btnElems[btnId];
    const fileInput = this._fileElems[btnId];
    const { onClick, onFile, cndFileInput } = handlers;

    if (!btn) return;

    // クリックイベント
    L.DomEvent.on(btn, "click", (e) => {
      L.DomEvent.preventDefault(e);

      // 条件判定ロジック
      let isFileMode = false;
      if (typeof cndFileInput === "function") {
        // 関数なら実行結果を使う (併用モード)
        isFileMode = cndFileInput(this._map, btnId);
      } else {
        // 値ならその真偽値を使う (true: ファイル専用 / undefined or false: クリック専用)
        isFileMode = !!cndFileInput;
      }

      if (isFileMode) {
        if (fileInput) {
          fileInput.value = "";
          fileInput.click();
        } else {
          console.warn(`Button ${btnId} needs fileInput: true`);
        }
      } else {
        if (onClick) onClick(this._map, e);
      }
    });

    // ファイル選択イベント
    if (fileInput && onFile) {
      L.DomEvent.on(fileInput, "change", (e) => {
        if (e.target.files && e.target.files[0]) {
          onFile(this._map, e.target.files[0], e);
        }
      });
    }
  },

  // ステータス管理用
  setStatus: function (btnId, status) {
    const el = this._btnElems[btnId];
    if (el) el.className = `btn status-${status}`;
  },
  getStatus: function (btnId) {
    const el = this._btnElems[btnId];
    if (!el) return null;
    const cls = [...el.classList].find((c) => c.startsWith("status-"));
    return cls ? cls.replace("status-", "") : null;
  },
  // -------------------------
  // active / non-active（機能状態）
  // -------------------------
  disable: function (btnId) {
    const el = this._btnElems[btnId];
    if (!el) return;
    el.classList.add("disabled");
  },

  enable: function (btnId) {
    const el = this._btnElems[btnId];
    if (!el) return;
    el.classList.remove("disabled");
  },
});
L.control.buttonGroup = (opts) => new L.Control.ButtonGroup(opts);
