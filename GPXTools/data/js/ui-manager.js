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
      const btnId = this.selector.controls[cfg.controlKey];
      const btn = document.getElementById(btnId);
      if (!btn) return;

      const isActive =
        mode === this.selector.constructor.Mode.DEFAULT || mode === m;

      btn.classList.toggle("active", isActive);
      btn.disabled = !isActive;
    });
  }

  // ---------------------------------------------------
  // STATE UI 更新（Handler → Selector → UIManager）
  // ---------------------------------------------------
  updateStateUI({ mode, label, canCancel }) {
    const ModeConfig = this.selector.constructor.ModeConfig;
    const cfg = ModeConfig[mode];

    // アクションボタンのラベル更新
    if (cfg) {
      const actionBtnId = this.selector.controls[cfg.controlKey];
      this.setButtonLabel(actionBtnId, label);
    }

    // キャンセルボタンの有効/無効
    const cancelBtn = document.getElementById(
      this.selector.controls.cancelActionBtnId
    );
    if (cancelBtn) {
      cancelBtn.disabled = !canCancel;
    }
  }

  // ---------------------------------------------------
  // GPX 読み込み
  // ---------------------------------------------------
  handleGpxLoad(e) {
    const file = e.target.files[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = (ev) => {
      const gpxText = ev.target.result;

      const tempService = new GPXService();
      tempService.loadFromXml(gpxText);

      const newPts = tempService.getTrkpts();
      newPts.forEach((p) => this.selector.addPoint(p));

      this.selector.zoomToMarkerByIndex(newPts.length - 1);
      e.target.value = "";
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
    const list = document.getElementById(this.selector.controls.pointListId);
    if (!list) return;

    list.innerHTML = "";

    const pts = this.selector.gpxService.getTrkpts();

    pts.forEach((p, i) => {
      const opt = document.createElement("option");
      opt.value = i;
      opt.textContent = `${i + 1}. ${p.name || p.desc || `${p.lat}, ${p.lon}`}`;
      list.appendChild(opt);
    });
  }

  // ---------------------------------------------------
  // pointList → 地図移動（★4: idx Zoom に再構築）
  // ---------------------------------------------------
  handlePointListChange() {
    const list = document.getElementById(this.selector.controls.pointListId);
    if (!list) return;

    const val = list.value;
    if (val === "" || isNaN(val)) return;

    const idx = parseInt(val, 10);

    // ★ markers 配列を触らない
    this.selector.zoomToMarkerByIndex(idx);
  }

}
