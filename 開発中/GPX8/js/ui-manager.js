import GPXService from "./gpx-service.js";
import { geoService } from "./components/geo-service.js";
import { FileService, notify } from "./api-utils.js";

export default class UIManager {
  constructor(selector) {
    this.selector = selector;
    // Leaflet-search.js の options.historyKey と完全に一致させる
    this.SEARCH_HISTORY_KEY = "leaflet_search_history_keyword_only";
  }

  // ---------------------------------------------------
  // UI 制御・更新
  // ---------------------------------------------------
  initUIHandlers() {}

  setButtonLabel(id, text) {
    const btn = document.getElementById(id);
    const label = btn?.querySelector(".label");
    if (label) label.textContent = text;
  }

  updateModeButtons(mode) {
    const ModeConfig = this.selector.constructor.ModeConfig;
    Object.entries(ModeConfig).forEach(([m, cfg]) => {
      const btnId = cfg.buttonId;
      const shouldEnable = m === mode || mode === this.selector.constructor.Mode.DEFAULT;
      if (shouldEnable) {
        this.selector.mapInitializer.groups.modeOptions.enable(btnId);
      } else {
        this.selector.mapInitializer.groups.modeOptions.disable(btnId);
      }
    });
  }

  updateStateUI({ buttonId, state, canCancel }) {
    this.selector.mapInitializer.groups.modeOptions.setStatus(buttonId, state);
    this.selector.mapInitializer.groups.modeOptions.setStatus(
      "cancel",
      canCancel ? "active" : "inactive"
    );
  }

  updateListUI() {
    this.selector.pointListControl.updateList();
  }

  // ---------------------------------------------------
  // GPX 読み込み（ルート情報）
  // ---------------------------------------------------
  async handleGpxLoad(file) {
    if (!file) return;
    try {
      const gpxText = await FileService.read(file);
      const tempService = new GPXService();
      tempService.loadFromXml(gpxText);
      const newPts = tempService.getTrkpts();
      this.selector.addPoints(newPts);
      this.selector.zoomToMarkerByIndex(newPts.length - 1);
      notify("GPXを読み込みました");
    } catch (e) {
      console.error("GPX読み込み失敗:", e);
    }
  }

  // ---------------------------------------------------
  // 公開：ルートGPX保存 (自治体名解決あり)
  // ---------------------------------------------------
  handleGpxSave = async () => {
    const pts = this.selector.gpxService.getTrkpts();
    // GPXService.TypeMap の muitiRoute に対応（属性として出力）
    pts.forEach((pt) => (pt.muitiRoute = "1"));

    const center = this.selector.map.getCenter();
    let locationName = "";
    try {
      const point = await geoService.resolve({ lat: center.lat, lon: center.lng });
      if (point && point.name) locationName = `【周辺】${point.name}`;
    } catch (e) {
      console.warn("自治体名取得失敗:", e);
    }

    const defaultFilename = locationName ? `${locationName}.gpx` : "route.gpx";
    await this._executeGpxSave(pts, defaultFilename);
  };

  // ---------------------------------------------------
  // 公開：検索履歴のGPX保存 (extensionsをそのままXML化)
  // ---------------------------------------------------
  handleHistorySave = async () => {
    const historyRaw = localStorage.getItem(this.SEARCH_HISTORY_KEY);
    if (!historyRaw) {
      notify("保存する履歴がありません");
      return;
    }

    try {
      const historyData = JSON.parse(historyRaw);
      
      // GPXService.createElementFromObject は extensions 以下の 
      // keyword, timestamp, count を再帰的に XML タグに変換する
      const pts = historyData.map(item => ({
        lat: item.lat,
        lon: item.lon,
        name: item.name,
        desc: item.desc,
        extensions: item.extensions // オブジェクトをそのまま渡す
      }));

      await this._executeGpxSave(pts, "検索履歴.gpx");
      notify("履歴を保存しました");
    } catch (e) {
      console.error("履歴保存失敗:", e);
    }
  };

  // ---------------------------------------------------
  // 公開：検索履歴のGPX読み込み (インポート・マージ)
  // ---------------------------------------------------
  handleHistoryLoad = async (file) => {
    if (!file) return;
    try {
      const gpxText = await FileService.read(file);
      const tempService = new GPXService();
      tempService.loadFromXml(gpxText);
      
      // GPXService.elementToObject により、XMLタグ構造が
      // 自動的に extensions オブジェクトとして復元される
      const importedPts = tempService.getTrkpts();

      if (!importedPts || importedPts.length === 0) {
        notify("有効な履歴データが見つかりません");
        return;
      }

      const currentHistoryRaw = localStorage.getItem(this.SEARCH_HISTORY_KEY);
      let history = currentHistoryRaw ? JSON.parse(currentHistoryRaw) : [];

      let addCount = 0;
      importedPts.forEach(pt => {
        // 重複判定: 座標(lat, lon) と 名称(name) で照合
        const isDuplicate = history.some(h => 
          h.lat === pt.lat && h.lon === pt.lon && h.name === pt.name
        );

        if (!isDuplicate) {
          const newEntry = {
            _id: "ID_" + Date.now() + Math.random(),
            lat: pt.lat,
            lon: pt.lon,
            name: pt.name,
            desc: pt.desc || "",
            extensions: pt.extensions || {} // 復元されたオブジェクトをそのまま格納
          };
          history.unshift(newEntry);
          addCount++;
        }
      });

      if (history.length > 2000) history = history.slice(0, 2000);
      localStorage.setItem(this.SEARCH_HISTORY_KEY, JSON.stringify(history));

      notify(`${addCount}件の履歴をインポートしました`);
    } catch (e) {
      console.error("履歴読み込み失敗:", e);
      notify("履歴のパースに失敗しました");
    }
  };

  // ---------------------------------------------------
  // 内部共通：GPX書き出し実行
  // ---------------------------------------------------
  async _executeGpxSave(pts, filename) {
    if (!pts || pts.length === 0) return;

    const tempService = new GPXService();
    tempService.setTrkpts(pts);
    const gpxText = tempService.toXml();

    await FileService.save(gpxText, {
      filename: filename,
      mimeType: "application/gpx+xml",
      extension: "gpx"
    });
  }
}