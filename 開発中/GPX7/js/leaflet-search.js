L.Control.SearchWithHistory = L.Control.extend({
  // デフォルトオプション
  options: {
    position: "topleft",
    placeholder: "場所を検索...",
    maxHistory: 2000,
    historyKey: "leaflet_search_history_keyword_only",
    nominatimUrl: "https://nominatim.openstreetmap.org/search",
    autoCollapse: true,
    onLocationSelected: null,
  },

  // コンストラクタ
  initialize: function (options) {
    // ここで引数 options とデフォルトの options をマージする
    L.setOptions(this, options);
  },

  onAdd: function (map) {
    this._map = map;

    // CSSクラス名は Leaflet の標準に従い 'leaflet-bar' などを混ぜるとスタイルが安定します
    const container = L.DomUtil.create(
      "div",
      "leaflet-search-control leaflet-bar"
    );

    // イベント伝播の防止
    L.DomEvent.disableClickPropagation(container);
    L.DomEvent.disableScrollPropagation(container);

    this._input = L.DomUtil.create("input", "leaflet-search-input", container);
    this._input.type = "text";
    this._input.placeholder = this.options.placeholder; // this.options を使用
    this._input.autocomplete = "off";

    this._ul = L.DomUtil.create("ul", "leaflet-search-suggestions", container);
    this._debounceTimer = null;

    // --- イベント設定 ---
    L.DomEvent.on(this._input, "input", this._onInput, this);
    L.DomEvent.on(this._input, "focus", this._onFocus, this);

    this._outsideClickHandler = (e) => {
      if (!container.contains(e.target)) this._ul.style.display = "none";
    };
    document.addEventListener("click", this._outsideClickHandler);

    return container;
  },

  // --- メソッド分離（可読性とバグ防止のため） ---
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

  // 既存のメソッド群（bindOnLocationSelected, _performSearch, etc...）をここに続ける
  bindOnLocationSelected: function (fn) {
    this.options.onLocationSelected = fn;
    return this;
  },

  _performSearch: async function (query) {
    const qLower = query.toLowerCase();
    const history = this._getHistory();

    const historyResults = history
      .filter((item) => {
        if (item.extensions && item.extensions.keyword) {
          return item.extensions.keyword.toLowerCase().includes(qLower);
        }
        return item.name.toLowerCase().includes(qLower);
      })
      .map((item) => ({ ...item, source: "history" }));

    try {
      const res = await fetch(
        `${this.options.nominatimUrl}?format=json&countrycodes=jp&accept-language=ja&q=${encodeURIComponent(
          query
        )}`
      );
      const data = await res.json();
      const webResults = data.map((item) => ({
        lat: parseFloat(item.lat),
        lon: parseFloat(item.lon),
        name: item.name || item.display_name.split(",")[0],
        desc: item.display_name,
        extensions: { keyword: query },
        source: "web",
      }));
      this._renderSuggestions([...historyResults, ...webResults]);
    } catch (err) {
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
      let metaText =
        isHistory && item.extensions ? `${item.extensions.count || 1}回` : "";

      li.innerHTML = `
        <span class="ls-badge ${
          isHistory ? "ls-badge-history" : "ls-badge-web"
        }">${isHistory ? "履歴" : "Web"}</span>
        <div class="item-content"><span class="item-name">${
          item.name
        }</span><span class="item-desc">${item.desc || ""}</span></div>
        <span class="ls-meta">${metaText}</span>
      `;
      L.DomEvent.on(li, "click", () => this._selectItem(item));
    });
    this._ul.style.display = "block";
  },

  _selectItem: function (item) {
    if (this.options.autoCollapse) this._ul.style.display = "none";

    const savedItem = this._saveToHistory(item);
    const targetId = savedItem._id; // このIDをクロージャに閉じ込める

    // 更新用関数: _idを元に特定の履歴を更新する
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
        console.log("履歴詳細更新完了:", target);
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
        _id: "ID_" + Date.now() + Math.random(), // ユニークIDの発行
        lat: newItem.lat,
        lon: newItem.lon,
        name: newItem.name,
        desc: newItem.desc || "",
        extensions: {
          keyword: (newItem.extensions && newItem.extensions.keyword) || "",
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
});

L.control.searchWithHistory = function (opts) {
  return new L.Control.SearchWithHistory(opts);
};
