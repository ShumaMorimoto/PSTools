/**
 * SearchControl.js
 * GeoService.search を使用して場所を検索し、履歴と統合するコンポーネント
 */
import { geoService } from "./geo-service.js";

export function initSearchControl() {
  if (L.Control.SearchWithHistory) return;

  L.Control.SearchWithHistory = L.Control.extend({
    options: {
      position: "topright",
      placeholder: "場所を検索...",
      maxHistory: 2000,
      markerHistory: null, // 外部から markerHistory インスタンスを注入
      onLocationSelected: null,
    },

    initialize: function (options) {
      L.setOptions(this, options);
      this._markerHistory = this.options.markerHistory; // インスタンスを保持
      this._rawResults = [];
      this._debounceTimer = null;
      this._candidateLayer = null;
    },

    onAdd: function (map) {
      this._map = map;
      this._container = L.DomUtil.create(
        "div",
        "leaflet-search-parent-container",
      );
      L.DomEvent.disableClickPropagation(this._container);

      const searchBox = L.DomUtil.create(
        "div",
        "leaflet-search-control leaflet-bar",
        this._container,
      );
      this._input = L.DomUtil.create(
        "input",
        "leaflet-search-input",
        searchBox,
      );
      this._input.type = "text";
      this._input.placeholder = this.options.placeholder;
      this._input.autocomplete = "off";

      this._clearBtn = L.DomUtil.create(
        "button",
        "search-clear-btn",
        searchBox,
      );
      this._clearBtn.innerHTML = "×";
      this._clearBtn.style.display = "none";

      this._panel = L.DomUtil.create(
        "div",
        "leaflet-search-side-panel",
        this._container,
      );
      this._panel.style.display = "none";

      // イベント登録
      L.DomEvent.on(
        this._clearBtn,
        "click",
        () => {
          this._input.value = "";
          this._clearBtn.style.display = "none";
          this._hidePanel();
          this._input.focus();
        },
        this,
      );

      L.DomEvent.on(this._input, "input", this._onInput, this);
      L.DomEvent.on(this._input, "keydown", this._onKeyDown, this);

      return this._container;
    },

    _onInput: function (e) {
      const query = e.target.value.trim();
      this._clearBtn.style.display = query.length > 0 ? "flex" : "none";
    },

    _onKeyDown: function (e) {
      if (e.keyCode === 13) {
        const query = this._input.value.trim();
        if (query.length >= 2) {
          this._performSearch(query);
        }
      }
    },

    _hidePanel: function () {
      this._panel.style.display = "none";
      if (this._candidateLayer) {
        this._map.removeLayer(this._candidateLayer);
        this._candidateLayer = null;
      }
    },

    _performSearch: async function (query) {
      try {
        // 1. 履歴からの取得（this._markerHistory の search 結果を map）
        const history = (this._markerHistory?.search(query) || []).map((h) => ({
          ...h,
          source: "history",
        }));

        // 2. Web検索結果を取得（ここを webMapped に統一して定義）
        const webMapped = (await geoService.search(query)).map((r) => ({
          ...r,
          source: "web",
        }));

        // 3. 結果の統合（これで ReferenceError は出ません）
        this._rawResults = [...history, ...webMapped];

        this._renderPanelLayout();
        this._applyFilter();
      } catch (err) {
        console.error("Search failed:", err);
      }
    },

    _renderPanelLayout: function () {
      this._panel.innerHTML = "";
      this._panel.style.display = "flex";

      const header = L.DomUtil.create("div", "panel-header", this._panel);
      this._countEl = L.DomUtil.create("span", "results-count", header);
      this._countEl.innerHTML = `検索結果: ${this._rawResults.length}件`;

      const closeBtn = L.DomUtil.create("button", "panel-close-btn", header);
      closeBtn.innerHTML = "×";
      L.DomEvent.on(closeBtn, "click", this._hidePanel, this);

      const filterBar = L.DomUtil.create("div", "filter-bar", this._panel);
      this._prefSelect = L.DomUtil.create("select", "filter-select", filterBar);
      this._muniSelect = L.DomUtil.create("select", "filter-select", filterBar);

      // 都道府県リスト作成 (JISコード順)
      const prefCodes = [
        ...new Set(
          this._rawResults
            .map((r) => r.extensions?.muniCd5?.substring(0, 2))
            .filter(Boolean),
        ),
      ].sort((a, b) => parseInt(a) - parseInt(b));

      this._prefSelect.innerHTML =
        '<option value="">都道府県</option>' +
        prefCodes
          .map((code) => {
            const anyMuniInPref = Array.from(geoService.muniMap.values()).find(
              (m) => m.muniCd5.startsWith(code),
            );

            const prefName = anyMuniInPref ? anyMuniInPref.prefecture : code;
            return `<option value="${code}">${prefName}</option>`;
          })
          .join("");

      L.DomEvent.on(
        this._prefSelect,
        "change",
        () => {
          this._updateMuniOptions();
          this._applyFilter();
        },
        this,
      );

      L.DomEvent.on(this._muniSelect, "change", this._applyFilter, this);

      this._listContainer = L.DomUtil.create(
        "div",
        "results-list-container",
        this._panel,
      );

      L.DomEvent.disableScrollPropagation(this._listContainer);
      L.DomEvent.disableClickPropagation(this._listContainer);

      this._updateMuniOptions();
      this._applyFilter();
    },

    _updateMuniOptions: function () {
      const selectedPrefCode = this._prefSelect.value;

      // 市区町村リスト作成 (JISコード順)
      const muniCodes = [
        ...new Set(
          this._rawResults
            .map((r) => r.extensions?.muniCd5)
            .filter(
              (c) => c && (!selectedPrefCode || c.startsWith(selectedPrefCode)),
            ),
        ),
      ].sort((a, b) => parseInt(a) - parseInt(b));

      this._muniSelect.innerHTML =
        '<option value="">市区町村</option>' +
        muniCodes
          .map((code) => {
            const muni = geoService.muniMap.get(code);
            const muniName = muni ? muni.municipality : code;
            return `<option value="${code}">${muniName}</option>`;
          })
          .join("");
    },

    _applyFilter: function () {
      const pCode = this._prefSelect.value;
      const mCode = this._muniSelect.value;
      const query = this._input.value.trim(); // ← キーワードを取得

      // 判定ロジックに query を確実に渡す
      const filtered = this._rawResults.filter((r) => {
        if (!this._markerHistory) return true;
        // markerHistory.match 内で name や keyword を query で判定しているため、これが必要
        return this._markerHistory.match(r, query, pCode, mCode);
      });

      // --- 以下、描画処理（省略なし） ---
      if (this._countEl) {
        this._countEl.innerHTML = `検索結果: ${filtered.length}件`;
      }

      if (this._candidateLayer) this._map.removeLayer(this._candidateLayer);
      this._candidateLayer = L.layerGroup().addTo(this._map);

      this._listContainer.innerHTML = "";

      if (filtered.length === 0) {
        const emptyMsg = L.DomUtil.create(
          "div",
          "search-no-result",
          this._listContainer,
        );
        emptyMsg.innerHTML = "該当する結果がありません";
        return;
      }

      filtered.forEach((item) => {
        // マーカー追加
        L.circleMarker([item.lat, item.lon], {
          radius: 7,
          fillColor: item.source === "history" ? "#4CAF50" : "#2196F3",
          color: "#ffffff",
          weight: 3,
          opacity: 1,
          fillOpacity: 0.8,
          pane: "markerPane",
        }).addTo(this._candidateLayer);

        // リスト追加
        const li = L.DomUtil.create("div", "search-item", this._listContainer);
        const isHist = item.source === "history";
        li.innerHTML = `
          <div class="ls-badge-container">
            <span class="ls-badge ${isHist ? "ls-badge-history" : "ls-badge-web"}">${isHist ? "履歴" : "地理院"}</span>
          </div>
          <div class="item-content">
            <div class="item-name">${item.name}</div>
            <div class="item-addr">${item.desc}</div>
          </div>`;

        if (isHist) {
          const deleteBtn = L.DomUtil.create("button", "item-delete-btn", li);
          deleteBtn.innerHTML = "🗑";
          L.DomEvent.on(deleteBtn, "click", (e) => {
            L.DomEvent.stopPropagation(e);
            this._deleteFromHistory(item);
          });
        }
        L.DomEvent.on(li, "click", () => this._selectItem(item));
      });
    },

    _deleteFromHistory: function (item) {
      if (this._markerHistory) {
        this._markerHistory.delete(item);
      }
      this._rawResults = this._rawResults.filter((r) => r !== item);
      this._applyFilter();
    },

    _selectItem: function (item) {
      // markerHistory.save() でカウントアップと重複排除を実行
      const savedItem = this._markerHistory
        ? this._markerHistory.save(item)
        : item;

      if (this.options.onLocationSelected)
        this.options.onLocationSelected(savedItem, this._map, this);
      this._map.flyTo([item.lat, item.lon], 16);
    },

    bindOnLocationSelected: function (fn) {
      this.options.onLocationSelected = fn;
      return this;
    },
  });

  L.control.searchWithHistory = function (opts) {
    return new L.Control.SearchWithHistory(opts);
  };
}
