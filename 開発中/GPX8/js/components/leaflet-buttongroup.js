// 1. initializerから呼べるように「export」を付ける
export function initButtonGroup() {
    
    // 2. 二重定義防止のガード
    if (L.Control.ButtonGroup) return;

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
                <a href="#" id="${btn.id}" class="btn status-default" title="${btn.title || ""}">
                    ${btn.icon}
                </a>
                ${
                    btn.fileInput
                        ? `<input type="file" id="${btn.id}_file" accept="${btn.accept || ""}" style="display:none;">`
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

        setButtonHandler: function (btnId, handlers) {
            const btn = this._btnElems[btnId];
            const fileInput = this._fileElems[btnId];
            const { onClick, onFile, cndFileInput } = handlers;

            if (!btn) return;

            L.DomEvent.on(btn, "click", (e) => {
                L.DomEvent.preventDefault(e);

                let isFileMode = false;
                if (typeof cndFileInput === "function") {
                    isFileMode = cndFileInput(this._map, btnId);
                } else {
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

            if (fileInput && onFile) {
                L.DomEvent.on(fileInput, "change", (e) => {
                    if (e.target.files && e.target.files[0]) {
                        onFile(this._map, e.target.files[0], e);
                    }
                });
            }
        },

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
} // ここで initButtonGroup の終わり