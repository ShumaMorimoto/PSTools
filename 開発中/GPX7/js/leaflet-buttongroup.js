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
        <a href="#" id="${btn.id}"
           class="btn status-default ${btn.enabled === false ? "disabled" : ""}"
           title="${btn.title || ""}">
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
      if (btn.fileInput) {
        this._fileElems[btn.id] = container.querySelector(`#${btn.id}_file`);
      }
    });

    return container;
  },

  onClick: function (btnId, handler) {
    const el = this._btnElems[btnId];
    if (!el) return;
    L.DomEvent.on(el, "click", (e) => {
      L.DomEvent.preventDefault(e);
      handler(this._map, e);
    });
  },

  onFile: function (btnId, handler) {
    const btn = this._btnElems[btnId];
    const fileInput = this._fileElems[btnId];
    if (!btn || !fileInput) return;

    L.DomEvent.on(btn, "click", (e) => {
      L.DomEvent.preventDefault(e);
      fileInput.click();
    });

    L.DomEvent.on(fileInput, "change", (e) => {
      handler(this._map, e.target.files[0], e);
    });
  },

  // -------------------------
  // 状態（UI 状態）
  // -------------------------
  setStatus: function (btnId, status) {
    const el = this._btnElems[btnId];
    if (!el) return;

    // 状態は 1 個だけ → className を上書きするだけ
    // active/non-active とは混ぜない
    const hasDisabled = el.classList.contains("disabled");
    el.className = `btn status-${status}` + (hasDisabled ? " disabled" : "");
  },

  getStatus: function (btnId) {
    const el = this._btnElems[btnId];
    if (!el) return null;
    // classList から status-◯◯ を探す
    const cls = [...el.classList].find((c) => c.startsWith("status-"));
    if (!cls) return null;

    return cls.replace("status-", "");
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
