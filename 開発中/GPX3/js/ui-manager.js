import GPXService from "./gpx-service.js";

export default class UIManager {
  constructor(selector) {
    this.selector = selector;
  }

  initUIHandlers() {
    document
      .getElementById(this.selector.controls.pointListId)
      .addEventListener("change", () => this.handlePointListChange());

    // ✅ GPX 読み込み
    this.initGpxLoadButton();

    // ✅ GPX 保存
    this.initGpxSaveButton();

    document
      .getElementById(this.selector.controls.reFetchBtnId)
      .addEventListener("click", () => this.reFetchAllAddresses());

    document
      .getElementById(this.selector.controls.clearMarkersBtnId)
      .addEventListener("click", () =>
        this.selector.markerHandler.clearMarkers()
      );

    document
      .getElementById(this.selector.controls.finishBtnId)
      .addEventListener("click", () => this.finish());
  }

  // -----------------------------
  // ✅ 任意ボタンのラベルを変更（汎用）
  // -----------------------------
  setButtonLabel(buttonId, label) {
    const btn = document.getElementById(buttonId);
    if (!btn) return;
    btn.textContent = label;
  }

  // -----------------------------
  // ✅ GPX 読み込み
  // -----------------------------
  initGpxLoadButton() {
    const input = document.getElementById(this.selector.controls.gpxInputId);
    if (!input) return;

    input.addEventListener("change", (e) => {
      const file = e.target.files[0];
      if (!file) return;

      const reader = new FileReader();
      reader.onload = (ev) => {
        const gpxText = ev.target.result;

        // ✅ 一時 GPXModel を UI 側で作る（責務分離）
        const tempService = new GPXService();
        tempService.loadFromXml(gpxText);

        const newPts = tempService.getTrkptList();

        // ✅ 正式 Model にこちらで反映
        newPts.forEach((p) => {
          const tp = this.selector.gpxService.addTrkpt(p);
          this.selector.markerHandler.addPoint(tp);
        });

        e.target.value = "";
      };
      reader.readAsText(file);
    });
  }

  // -----------------------------
  // ✅ GPX 保存
  // -----------------------------
  initGpxSaveButton() {
    const btn = document.getElementById(this.selector.controls.gpxSaveId);
    if (!btn) return;

    btn.addEventListener("click", async () => {
      const gpx = this.selector.gpxService.toXml();
      await this.saveGpx("route.gpx", gpx);
    });
  }

  // -----------------------------
  // ✅ 保存ダイアログ
  // -----------------------------
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

  // -----------------------------
  // ✅ ダウンロード fallback
  // -----------------------------
  downloadText(filename, text) {
    const blob = new Blob([text], { type: "application/gpx+xml" });
    const url = URL.createObjectURL(blob);

    const a = document.createElement("a");
    a.href = url;
    a.download = filename;
    a.click();

    URL.revokeObjectURL(url);
  }

  // -----------------------------
  // ✅ pointList UI 更新
  // -----------------------------
  updateListUI() {
    const list = document.getElementById(this.selector.controls.pointListId);
    if (!list) return;

    list.innerHTML = "";

    const pts = this.selector.gpxService.getTrkptList();

    pts.forEach((p, i) => {
      const opt = document.createElement("option");
      opt.value = i;
      opt.textContent = `${i + 1}. ${p.name || p.desc || `${p.lat}, ${p.lon}`}`;
      list.appendChild(opt);
    });
  }

  // -----------------------------
  // ✅ pointList → 地図移動
  // -----------------------------
  handlePointListChange() {
    const list = document.getElementById(this.selector.controls.pointListId);
    if (!list) return;

    const val = list.value;
    if (val === "" || isNaN(val)) return;

    const idx = parseInt(val, 10);
    const marker = this.selector.markerHandler.markers[idx].m;

    if (!marker) return;
    this.selector.markerHandler.zoomToMarker(marker);
  }

  // -----------------------------
  // ✅ 住所情報を再取得する
  // -----------------------------
  reFetchAllAddresses() {
    this.selector.markerHandler.reFetchAllAddresses();
  }

  // -----------------------------
  // ✅ finish
  // -----------------------------
  finish() {
    const btn = document.getElementById(this.selector.controls.finishBtnId);

    if (btn.dataset.state === "done") {
      window.close();
      return;
    }

    btn.textContent = "送信中...";
    btn.disabled = true;

    fetch("/choice", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(this.selector.gpxService.toJson()),
    })
      .then(() => fetch("/done", { method: "POST" }))
      .then(() => {
        btn.textContent = "完了 (閉じる)";
        btn.disabled = false;
        btn.dataset.state = "done";
        btn.style.backgroundColor = "#28a745";
      })
      .catch((e) => {
        console.error("送信エラー:", e);
        alert("サーバーへの送信に失敗しました。");
        btn.textContent = "登録";
        btn.disabled = false;
      });
  }
}