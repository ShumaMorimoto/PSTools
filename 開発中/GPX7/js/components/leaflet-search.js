let muniCache = null; // キャッシュ用変数をファイルスコープで定義

async function loadMunicipalitiesInternal() {
  if (muniCache) return muniCache;
  // パスは実行環境に合わせて調整してください
  const res = await fetch("./../../municipalities.json");
  muniCache = await res.json();
  return muniCache;
}
L.Control.SearchWithHistory = L.Control.extend({
  options: {
    position: "topleft",
    placeholder: "場所を検索...",
    maxHistory: 2000,
    historyKey: "leaflet_search_history_keyword_only",
    // ★ 'gsi' (国土地理院) または 'nominatim' (OSM) を指定
    provider: "gsi",
    autoCollapse: true,
    onLocationSelected: null,
  },

  initialize: function (options) {
    L.setOptions(this, options);
  },

  onAdd: function (map) {
    this._map = map;
    const container = L.DomUtil.create(
      "div",
      "leaflet-search-control leaflet-bar"
    );

    L.DomEvent.disableClickPropagation(container);
    L.DomEvent.disableScrollPropagation(container);

    this._input = L.DomUtil.create("input", "leaflet-search-input", container);
    this._input.type = "text";
    this._input.placeholder = this.options.placeholder;
    this._input.autocomplete = "off";

    this._ul = L.DomUtil.create("ul", "leaflet-search-suggestions", container);
    this._debounceTimer = null;

    L.DomEvent.on(this._input, "input", this._onInput, this);
    L.DomEvent.on(this._input, "focus", this._onFocus, this);

    this._outsideClickHandler = (e) => {
      if (!container.contains(e.target)) this._ul.style.display = "none";
    };
    document.addEventListener("click", this._outsideClickHandler);

    return container;
  },

  _onInput: function (e) {
    const query = e.target.value.trim();
    clearTimeout(this._debounceTimer);
    if (query.length < 2) {
      this._ul.style.display = "none";
      return;
    }
    this._debounceTimer = setTimeout(() => this._performSearch(query), 300);
  },

  _onFocus: function () {
    if (this._input.value === "") {
      const history = this._getHistory();
      if (history.length > 0) {
        this._renderSuggestions(
          history.map((h) => ({ ...h, source: "history" }))
        );
      }
    }
  },
  
  // ★ 検索実行ロジックの切り分け
  _performSearch: async function (query) {
    const qLower = query.toLowerCase();
    const history = this._getHistory();

    // 1. 履歴からのフィルタリング
    const historyResults = history
      .filter((item) => {
        const keyword = item.extensions?.keyword || item.name;
        return keyword.toLowerCase().includes(qLower);
      })
      .map((item) => ({ ...item, source: "history" }));

    try {
      let webResults = [];

      // 2. プロバイダーごとのフェッチとパース
      if (this.options.provider === "gsi") {
        // --- 国土地理院 (GSI) ---
        const res = await fetch(
          `https://msearch.gsi.go.jp/address-search/AddressSearch?q=${encodeURIComponent(
            query
          )}`
        );
        const data = await res.json();

        // 自治体マスタをロード
        const muniData = await loadMunicipalitiesInternal();

        webResults = data.map((item) => {
          const props = item.properties;
          let muniInfo = null;

          // addressCode（自治体コード）が存在する場合、マスタから検索
          if (props.addressCode) {
            // muniCd5 (5桁) で照合
            muniInfo =
              muniData.municipalities.find(
                (m) => m.muniCd5 === props.addressCode
              ) || null;
          }

          return {
            lat: item.geometry.coordinates[1],
            lon: item.geometry.coordinates[0],
            name: props.title,
            desc: "国土地理院 地名検索",
            extensions: {
              keyword: query,
              ...(muniInfo || {}), // 見つかった場合のみ展開してマージ
            },
            source: "web",
          };
        });
      } else {
        // --- Nominatim (OSM) ---
        const url = `https://nominatim.openstreetmap.org/search?format=json&countrycodes=jp&accept-language=ja&q=${encodeURIComponent(
          query
        )}`;
        const res = await fetch(url);
        const data = await res.json();
        webResults = data.map((item) => ({
          lat: parseFloat(item.lat),
          lon: parseFloat(item.lon),
          name: item.name || item.display_name.split(",")[0],
          desc: item.display_name,
          extensions: { keyword: query },
          source: "web",
        }));
      }

      this._renderSuggestions([...historyResults, ...webResults]);
    } catch (err) {
      console.error("Search Error:", err);
      this._renderSuggestions(historyResults);
    }
  },

  _renderSuggestions: function (results) {
    this._ul.innerHTML = "";
    if (results.length === 0) {
      this._ul.style.display = "none";
      return;
    }
    results.slice(0, 10).forEach((item) => {
      const li = L.DomUtil.create("li", "", this._ul);
      const isHistory = item.source === "history";
      const badgeText = isHistory
        ? "履歴"
        : this.options.provider === "gsi"
        ? "地理院"
        : "Web";

      let metaText =
        isHistory && item.extensions ? `${item.extensions.count || 1}回` : "";

      li.innerHTML = `
        <span class="ls-badge ${
          isHistory ? "ls-badge-history" : "ls-badge-web"
        }">${badgeText}</span>
        <div class="item-content">
          <span class="item-name">${item.name}</span>
          <span class="item-desc">${item.desc || ""}</span>
        </div>
        <span class="ls-meta">${metaText}</span>
      `;
      L.DomEvent.on(li, "click", () => this._selectItem(item));
    });
    this._ul.style.display = "block";
  },

  _selectItem: function (item) {
    if (this.options.autoCollapse) this._ul.style.display = "none";
    const savedItem = this._saveToHistory(item);
    const targetId = savedItem._id;

    const updateHistory = (params) => {
      const history = this._getHistory();
      const target = history.find((h) => h._id === targetId);
      if (target) {
        if (params.lat !== undefined) target.lat = params.lat;
        if (params.lon !== undefined) target.lon = params.lon;
        if (params.name !== undefined) target.name = params.name;
        if (params.desc !== undefined) target.desc = params.desc;
        if (params.keyword !== undefined) {
          if (!target.extensions) target.extensions = {};
          target.extensions.keyword = params.keyword;
        }
        target.extensions.timestamp = new Date().toISOString();
        localStorage.setItem(this.options.historyKey, JSON.stringify(history));
      }
    };

    if (this.options.onLocationSelected) {
      this.options.onLocationSelected(
        savedItem,
        this._map,
        this,
        updateHistory
      );
    }
  },

  _getHistory: function () {
    const json = localStorage.getItem(this.options.historyKey);
    return json ? JSON.parse(json) : [];
  },

  _saveToHistory: function (newItem) {
    let history = this._getHistory();
    const now = new Date().toISOString();
    const existingIndex = history.findIndex(
      (h) =>
        h.extensions?.keyword === newItem.extensions?.keyword &&
        Math.abs(h.lat - newItem.lat) < 0.0001 &&
        Math.abs(h.lon - newItem.lon) < 0.0001
    );

    let targetItem;
    if (existingIndex > -1) {
      targetItem = history[existingIndex];
      targetItem.extensions.count = (targetItem.extensions.count || 1) + 1;
      targetItem.extensions.timestamp = now;
      if (!targetItem._id) targetItem._id = "ID_" + Date.now() + Math.random();
      history.splice(existingIndex, 1);
    } else {
      targetItem = {
        _id: "ID_" + Date.now() + Math.random(),
        lat: newItem.lat,
        lon: newItem.lon,
        name: newItem.name,
        desc: newItem.desc || "",
        extensions: {
          keyword: newItem.extensions?.keyword || "",
          timestamp: now,
          count: 1,
        },
      };
    }
    history.unshift(targetItem);
    if (history.length > this.options.maxHistory) history.pop();
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
