import GPXService from "./gpx-service.js";
import { fetchMuniInfo } from "./api-utils.js";

export default class UIManager {
  constructor(selector) {
    this.selector = selector;
  }

  // ---------------------------------------------------
  // 初期化
  // ---------------------------------------------------
  initUIHandlers() {}

  // ---------------------------------------------------
  // 汎用：ボタンラベル変更
  // ---------------------------------------------------
  setButtonLabel(id, text) {
    const btn = document.getElementById(id);
    const label = btn?.querySelector(".label");
    if (label) label.textContent = text;
  }

  // ---------------------------------------------------
  // MODE ボタン UI 更新（ModeConfig ベース）
  // ---------------------------------------------------
  updateModeButtons(mode) {
    const ModeConfig = this.selector.constructor.ModeConfig;

    Object.entries(ModeConfig).forEach(([m, cfg]) => {
      const btnId = cfg.buttonId;

      // ★ 条件：カレントMODEと一致 or カレントMODEがDEFAULT
      const shouldEnable = m === mode || mode === this.selector.constructor.Mode.DEFAULT;

      if (shouldEnable) {
        this.selector.mapInitializer.groups.modeOptions.enable(btnId);
      } else {
        this.selector.mapInitializer.groups.modeOptions.disable(btnId);
      }
    });
  }
  updateStateUI({ buttonId, state, canCancel }) {
    // ① 対象ボタンのステータス更新
    this.selector.mapInitializer.groups.modeOptions.setStatus(buttonId, state);

    // ② キャンセルボタンのステータス更新
    this.selector.mapInitializer.groups.modeOptions.setStatus(
      "cancel",
      canCancel ? "active" : "inactive"
    );
  }

  // ---------------------------------------------------
  // GPX 読み込み
  // ---------------------------------------------------
  handleGpxLoad(file) {
    if (!file) return;

    const reader = new FileReader();
    reader.onload = (ev) => {
      const gpxText = ev.target.result;

      const tempService = new GPXService();
      tempService.loadFromXml(gpxText);

      const newPts = tempService.getTrkpts();
      this.selector.addPoints(newPts);

      this.selector.zoomToMarkerByIndex(newPts.length - 1);
    };
    reader.readAsText(file);
  }

  // ---------------------------------------------------
  // GPX 保存
  // ---------------------------------------------------
  handleGpxSave = async () => {
    const pts = this.selector.gpxService.getTrkpts();
    pts.forEach((pt) => (pt.muitiRoute = "1"));

    const gpx = this.selector.gpxService.toXml();

    const center = this.selector.map.getCenter();
    const muni = await fetchMuniInfo(center.lat, center.lng);

    const filename = muni ? `【周辺】${muni.municipality}.gpx` : "route.gpx";

    await this.saveGpx(filename, gpx);
  };

  // ---------------------------------------------------
  // 保存ダイアログ
  // ---------------------------------------------------
  async saveGpx(filename, text) {
    if (window.showSaveFilePicker) {
      const opts = {
        suggestedName: filename,
        types: [
          {
            description: "GPXファイル",
            accept: { "application/gpx+xml": [".gpx"] },
          },
        ],
      };

      try {
        const handle = await window.showSaveFilePicker(opts);
        const writable = await handle.createWritable();
        await writable.write(text);
        await writable.close();
        return;
      } catch (e) {
        console.warn("保存キャンセル or エラー:", e);
        return;
      }
    }

    this.downloadText(filename, text);
  }

  // ---------------------------------------------------
  // ダウンロード fallback
  // ---------------------------------------------------
  downloadText(filename, text) {
    const blob = new Blob([text], { type: "application/gpx+xml" });
    const url = URL.createObjectURL(blob);

    const a = document.createElement("a");
    a.href = url;
    a.download = filename;
    a.click();

    URL.revokeObjectURL(url);
  }

  // ---------------------------------------------------
  // pointList UI 更新
  // ---------------------------------------------------
  updateListUI() {
    this.selector.pointListControl.updateList();
  }
}
