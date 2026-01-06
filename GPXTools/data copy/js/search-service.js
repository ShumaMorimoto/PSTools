export default class SearchService {
  constructor() {
    this.history = this._loadHistory();
    this.lastKeyword = "";
    this.originalProvider = new window.GeoSearch.OpenStreetMapProvider();
  }

  // ----------------------------------------------------
  // Provider が呼ぶ search()
  // （TrkptProvider のロジックをそのまま移植）
  // ----------------------------------------------------
  async search({ query }) {

    // 補完前キーワード保持
    if (query.length <= 15) {
      this.lastKeyword = query;
    }

    // 履歴マッチ
    const historyMatches = this.history
      .filter(h => h.name.includes(query))
      .map(h => ({
        label: h.name,
        x: h.lon,
        y: h.lat,
        bounds: null,
        raw: h,
        isHistory: true
      }));

    // API検索（OSM）
    const apiResults = await this.originalProvider.search({ query });

    const apiConverted = apiResults.map(r => ({
      label: r.label,
      x: r.x,
      y: r.y,
      bounds: r.bounds,
      raw: this._convertToTrkpt(r, this.lastKeyword),
      isHistory: false
    }));

    return [...historyMatches, ...apiConverted];
  }

  // ----------------------------------------------------
  // showlocation の事後処理（履歴更新）
  // Initializer から呼ばれる
  // ----------------------------------------------------
  showLocation(location) {
    const trkpt = location.raw ?? location;

    const existing = this.history.find(
      h => h.lat === trkpt.lat && h.lon === trkpt.lon
    );

    if (existing) {
      existing.extensions.count++;
    } else {
      this.history.push(trkpt);
    }

    this._saveHistory();
  }

  // ----------------------------------------------------
  // trkpt 変換（TrkptProvider の convertToTrkpt）
  // ----------------------------------------------------
  _convertToTrkpt(result, keyword) {
    return {
      lat: result.y,
      lon: result.x,
      name: result.label,
      desc: `検索: ${keyword}`,
      extensions: {
        keyword,
        provider: "OSM",
        timestamp: Date.now(),
        count: 1
      }
    };
  }

  // ----------------------------------------------------
  // 履歴ロード／保存
  // ----------------------------------------------------
  _loadHistory() {
    const json = localStorage.getItem("searchHistory");
    if (!json) return [];
    try { return JSON.parse(json); }
    catch { return []; }
  }

  _saveHistory() {
    localStorage.setItem("searchHistory", JSON.stringify(this.history));
  }
}