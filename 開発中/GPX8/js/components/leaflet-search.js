// ファイルの冒頭で GeoService をインポートしているか確認
import { geoService } from "./geo-service.js";

let muniCache = null;
async function loadMunicipalitiesInternal() {
  if (muniCache) return muniCache;
  const res = await fetch("./../../municipalities.json");
  muniCache = await res.json();
  return muniCache;
}

export function initSearchControl() {
  if (L.Control.SearchWithHistory) return;

  L.Control.SearchWithHistory = L.Control.extend({
    options: {
      position: "topright",
      placeholder: "場所を検索...",
      maxHistory: 2000,
      historyKey: "leaflet_search_history_keyword_only",
      onLocationSelected: null,
    },

    initialize: function (options) {
      L.setOptions(this, options);
      this._rawResults = [];
      this._debounceTimer = null;
      this._abortController = null;
      this._candidateLayer = null;
    },

    onAdd: function (map) {
      this._map = map;
      this._container = L.DomUtil.create(
        "div",
        "leaflet-search-parent-container"
      );
      L.DomEvent.disableClickPropagation(this._container);

      const searchBox = L.DomUtil.create(
        "div",
        "leaflet-search-control leaflet-bar",
        this._container
      );
      this._input = L.DomUtil.create(
        "input",
        "leaflet-search-input",
        searchBox
      );
      this._input.type = "text";
      this._input.placeholder = this.options.placeholder;
      this._input.autocomplete = "off";

      this._clearBtn = L.DomUtil.create(
        "button",
        "search-clear-btn",
        searchBox
      );
      this._clearBtn.innerHTML = "×";
      this._clearBtn.style.display = "none";

      this._panel = L.DomUtil.create(
        "div",
        "leaflet-search-side-panel",
        this._container
      );
      this._panel.style.display = "none";

      L.DomEvent.on(
        this._clearBtn,
        "click",
        () => {
          this._input.value = "";
          this._clearBtn.style.display = "none";
          this._hidePanel();
          this._input.focus();
        },
        this
      );

      L.DomEvent.on(this._input, "input", this._onInput, this);
      return this._container;
    },

    _onInput: function (e) {
      const query = e.target.value.trim();
      this._clearBtn.style.display = query.length > 0 ? "flex" : "none";
      clearTimeout(this._debounceTimer);
      if (query.length < 2) {
        this._hidePanel();
        return;
      }
      this._debounceTimer = setTimeout(() => this._performSearch(query), 300);
    },

    _hidePanel: function () {
      this._panel.style.display = "none";
      if (this._candidateLayer) {
        this._map.removeLayer(this._candidateLayer);
        this._candidateLayer = null;
      }
    },

    _performSearch: async function (query) {
      if (this._abortController) this._abortController.abort();
      this._abortController = new AbortController();
      try {
        const res = await fetch(
          `https://msearch.gsi.go.jp/address-search/AddressSearch?q=${encodeURIComponent(
            query
          )}`,
          { signal: this._abortController.signal }
        );
        const data = await res.json();

        const historyJson = localStorage.getItem(this.options.historyKey);
        const history = (historyJson ? JSON.parse(historyJson) : [])
          .filter((h) =>
            (h.extensions?.keyword || h.name)
              .toLowerCase()
              .includes(query.toLowerCase())
          )
          .map((h) => ({ ...h, source: "history" }));

        // 1. まず Web検索結果のベースを作成
        const webResults = await Promise.all(
          data.map(async (item) => {
            const props = item.properties;

            // 暫定的なオブジェクトを作成
            let resultItem = {
              lat: item.geometry.coordinates[1],
              lon: item.geometry.coordinates[0],
              name: props.title,
              desc: props.title, // resolveAddress で補完される前のベース
              extensions: {
                keyword: query,
                muniCd5: props.addressCode
                  ? String(props.addressCode).padStart(5, "0")
                  : null,
                town: "", // 検索APIの段階では空
              },
              source: "web",
            };

            // 2. 作成した resolveAddress を呼び出して、不足分を「非破壊的」に補完
            // ここで muniCd5 による特定、desc からの逆引き、必要に応じた座標解決が行われます
            resultItem = await geoService.resolveAddress(resultItem);

            return resultItem;
          })
        );
        this._rawResults = [...history, ...webResults];
        this._renderPanelLayout();
        this._applyFilter();
      } catch (err) {
        if (err.name !== "AbortError") console.error(err);
      }
    },

    _renderPanelLayout: function () {
      this._panel.innerHTML = "";
      this._panel.style.display = "flex";
      const header = L.DomUtil.create("div", "panel-header", this._panel);
      header.innerHTML = `<span class="results-count">検索結果: ${this._rawResults.length}件</span>`;
      const closeBtn = L.DomUtil.create("button", "panel-close-btn", header);
      closeBtn.innerHTML = "×";
      L.DomEvent.on(closeBtn, "click", this._hidePanel, this);

      const filterBar = L.DomUtil.create("div", "filter-bar", this._panel);
      this._prefSelect = L.DomUtil.create("select", "filter-select", filterBar);
      this._muniSelect = L.DomUtil.create("select", "filter-select", filterBar);

      const prefMap = new Map();
      this._rawResults.forEach((r) => {
        if (r.extensions?.prefecture) {
          if (!prefMap.has(r.extensions.prefecture))
            prefMap.set(
              r.extensions.prefecture,
              parseInt(r.extensions.prefecture_code || "99", 10)
            );
        }
      });
      const sortedPrefs = Array.from(prefMap.keys()).sort(
        (a, b) => prefMap.get(a) - prefMap.get(b)
      );
      this._prefSelect.innerHTML =
        '<option value="">都道府県</option>' +
        sortedPrefs.map((p) => `<option value="${p}">${p}</option>`).join("");
      L.DomEvent.on(
        this._prefSelect,
        "change",
        () => {
          this._updateMuniOptions();
          this._applyFilter();
        },
        this
      );
      L.DomEvent.on(this._muniSelect, "change", this._applyFilter, this);
      this._listContainer = L.DomUtil.create(
        "div",
        "results-list-container",
        this._panel
      );
      this._updateMuniOptions();
    },

    _updateMuniOptions: function () {
      const selectedPref = this._prefSelect.value;
      const muniSet = new Set();
      this._rawResults.forEach((r) => {
        if (!selectedPref || r.extensions?.prefecture === selectedPref) {
          if (r.extensions?.municipality)
            muniSet.add(r.extensions.municipality);
        }
      });
      const sortedMunis = Array.from(muniSet).sort();
      this._muniSelect.innerHTML =
        '<option value="">市区町村</option>' +
        sortedMunis.map((m) => `<option value="${m}">${m}</option>`).join("");
    },

    _applyFilter: function () {
      const p = this._prefSelect.value;
      const m = this._muniSelect.value;
      const filtered = this._rawResults.filter(
        (r) =>
          (!p || r.extensions?.prefecture === p) &&
          (!m || r.extensions?.municipality === m)
      );

      if (this._candidateLayer) this._map.removeLayer(this._candidateLayer);
      this._candidateLayer = L.layerGroup().addTo(this._map);
      filtered.forEach((item) => {
        L.circleMarker([item.lat, item.lon], {
          radius: 7,
          fillColor: item.source === "history" ? "#4CAF50" : "#2196F3",
          color: "#ffffff",
          weight: 3,
          opacity: 1,
          fillOpacity: 0.8,
          pane: "markerPane",
        }).addTo(this._candidateLayer);
      });

      this._listContainer.innerHTML = "";
      filtered.forEach((item) => {
        const li = L.DomUtil.create("div", "search-item", this._listContainer);
        const isHist = item.source === "history";

        // 構造を整理：badge、content、delete-btn を明確に分ける
        li.innerHTML = `
          <div class="ls-badge-container">
            <span class="ls-badge ${
              isHist ? "ls-badge-history" : "ls-badge-web"
            }">
              ${isHist ? "履歴" : "地理院"}
            </span>
          </div>
          <div class="item-content">
            <div class="item-name">${item.name}</div>
            <div class="item-addr">${item.desc}</div>
          </div>
        `;

        // 履歴削除ボタン
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
      if (!confirm(`「${item.name}」を履歴から削除しますか？`)) return;

      const historyJson = localStorage.getItem(this.options.historyKey);
      if (!historyJson) return;

      let history = JSON.parse(historyJson);
      // ID または座標で一致するものを削除
      history = history.filter((h) => {
        if (item._id && h._id === item._id) return false;
        return !(
          Math.abs(h.lat - item.lat) < 0.0001 &&
          Math.abs(h.lon - item.lon) < 0.0001
        );
      });
      localStorage.setItem(this.options.historyKey, JSON.stringify(history));
      // 現在のメモリ上の結果リストからも削除して再描画
      this._rawResults = this._rawResults.filter((r) => r !== item);
      this._applyFilter();
    },

    _selectItem: function (item) {
      const savedItem = this._saveToHistory(item);
      if (this.options.onLocationSelected)
        this.options.onLocationSelected(savedItem, this._map, this);
      this._map.flyTo([item.lat, item.lon], 16);
    },

    _saveToHistory: function (newItem) {
      const historyJson = localStorage.getItem(this.options.historyKey);
      let history = historyJson ? JSON.parse(historyJson) : [];
      const now = new Date().toISOString();

      // 1. まず ID で検索（ドラッグ更新用）、なければ座標で検索（新規登録時の重複防止）
      let existingIndex = history.findIndex(
        (h) => newItem._id && h._id === newItem._id
      );

      if (existingIndex === -1) {
        existingIndex = history.findIndex(
          (h) =>
            Math.abs(h.lat - newItem.lat) < 0.0001 &&
            Math.abs(h.lon - newItem.lon) < 0.0001
        );
      }

      let targetItem;
      if (existingIndex > -1) {
        // 既存更新
        targetItem = history[existingIndex];
        targetItem.lat = newItem.lat; // 座標を最新に更新
        targetItem.lon = newItem.lon;
        targetItem.name = newItem.name;
        targetItem.desc = newItem.desc;
        targetItem.extensions = {
          ...targetItem.extensions,
          ...newItem.extensions,
          timestamp: now,
        };
        history.splice(existingIndex, 1);
      } else {
        // 新規追加
        targetItem = {
          _id: newItem._id || "ID_" + Date.now(), // IDがなければ発行
          lat: newItem.lat,
          lon: newItem.lon,
          name: newItem.name,
          desc: newItem.desc,
          extensions: { ...newItem.extensions, count: 1, timestamp: now },
          source: "history",
        };
      }
      history.unshift(targetItem);
      localStorage.setItem(this.options.historyKey, JSON.stringify(history));
      return targetItem;
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
