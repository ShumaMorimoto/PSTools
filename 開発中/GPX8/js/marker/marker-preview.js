import { geoService } from "./../components/geo-service.js";
import {
  markerEvents,
  MarkerEventTypes,
  dispatchMarkerEvent,
} from "../marker/marker-events.js";
import { markerHistory } from "../marker/marker-history.js";

/**
 * 検索プレビューと自治体履歴の描画・管理を一元化するクラス。
 */
export default class MarkerPreview {
  constructor(handler) {
    this.handler = handler;
    this.searchMarkers = []; // 検索プレビュー用（個別に管理）
    this.historyGroup = L.layerGroup(); // 自治体履歴用（一括管理）

    if (this.handler.map) {
      this.historyGroup.addTo(this.handler.map);
    }

    this.onSelected = this.onSelected.bind(this);

    // データ更新時にポップアップをリフレッシュ
    markerEvents.addEventListener(MarkerEventTypes.POINT_UPDATED, (e) => {
      const { point } = e.detail;
      const pm = this.getMarkerByPoint(point);
      if (pm) this.handler.popup.bindPreview(pm);
    });
  }

  /**
   * 🚩 MarkerBoundary.js から呼ばれる必須メソッド (1/2)
   * 編集モード切替時にマーカーを触れるようにするか制御
   */
  setInteractive(enabled) {
    const mode = enabled ? "auto" : "none";

    // 🚩 履歴グループ内の全マーカーを確実にループして pointer-events を書き換える
    this.historyGroup.eachLayer((marker) => {
      marker.options.interactive = enabled;
      const el = marker.getElement();
      if (el) {
        el.style.pointerEvents = mode; // 🚩 ここでクリックの可否を強制
      }
      if (!enabled && marker.getPopup()) marker.closePopup();
    });

    // 検索結果側も同様
    this.searchMarkers.forEach((marker) => {
      marker.options.interactive = enabled;
      const el = marker.getElement();
      if (el) el.style.pointerEvents = mode;
    });
  }

  /**
   * 🚩 MarkerBoundary.js から呼ばれる必須メソッド (2/2)
   * 座標(trkpt)に一致するマーカー実体を探して返す
   */
  getMarkerByPoint(point) {
    if (!point) return null;

    // 1. 検索プレビュー配列から探す
    const s = this.searchMarkers.find((m) => m.trkpt === point);
    if (s) return s;

    // 2. 履歴グループから探す
    let h = null;
    this.historyGroup.eachLayer((marker) => {
      if (
        marker.trkpt === point ||
        (marker.trkpt.id && marker.trkpt.id === point.id)
      ) {
        h = marker;
      }
    });
    return h;
  }

  /**
   * 自治体内の履歴を一括描画
   */
  plotMuniHistory(items) {
    this.historyGroup.clearLayers();
    items.forEach((item) => this.add(item, "history"));
  }

  /**
   * 検索結果などが選択された時
   */
  async onSelected(item) {
    this.clearSearchPreviews();
    const trkpt = { ...item };
    const pm = this.add(trkpt, "search");

    if (item.source === "web") {
      try {
        await geoService.resolveAddress(pm.trkpt);
        markerHistory.save(pm.trkpt);
        dispatchMarkerEvent(MarkerEventTypes.POINT_UPDATED, {
          point: pm.trkpt,
        });
      } catch (err) {
        console.error("プレビュー住所補完失敗:", err);
      }
    }
  }

  /**
   * 汎用的なマーカー追加
   */
  add(trkpt, mode = "search") {
    return this._createMarker(trkpt, mode);
  }

  /**
   * マーカー作成の核心部
   */
  _createMarker(trkpt, mode) {
    const isHistory = mode === "history";
    const icon = isHistory ? this._getFootprintIcon() : this._getSearchIcon();

    const pm = L.marker([trkpt.lat, trkpt.lon], {
      icon: icon,
      zIndexOffset: isHistory ? 1000 : 2000,
      draggable: true,
      interactive: true,
    });

pm.trkpt = trkpt;

    // --- 🚩 修正：イベントを待たずに、追加処理の後に直接実行する関数 ---
    const syncPointerEvents = () => {
      const el = pm.getElement();
      if (el) {
        // console.log("Applying style directly for:", trkpt.name);
        const isIdle = this.handler.state === "idle";
        el.style.pointerEvents = isIdle ? "auto" : "none";
      } else {
        // 万が一DOMがまだなければ、一度だけaddイベントを待つ（念のための保険）
        pm.once("add", () => {
          const el = pm.getElement();
          if (el) {
            const isIdle = this.handler.state === "idle";
            el.style.pointerEvents = isIdle ? "auto" : "none";
          }
        });
      }
    };

    // レイヤーへの追加
    if (isHistory) {
      this.historyGroup.addLayer(pm); // 🚩 ここで実質的に add される
    } else {
      if (this.handler.map) {
        pm.addTo(this.handler.map);
        this.searchMarkers.push(pm);
        this.handler.map.setView(pm.getLatLng(), 16);
        pm._timer = setTimeout(() => this.remove(pm), 180000);
      }
    }

    // 🚩 追加が終わった直後に実行
    syncPointerEvents();

    
    // --- 🚩 追記：addイベントが間に合わなかった場合（既にDOMがある場合）の予備処理 ---
    const el = pm.getElement();
    if (el && !el.style.pointerEvents) {
      const isIdle = this.handler.state === "idle";
      el.style.pointerEvents = isIdle ? "auto" : "none";
    }

    // 共通のポップアップ処理
    if (this.handler.popup) {
      this.handler.popup.bindPreview(pm);
    }

    // 履歴マーカーでもクリックでポップアップを出すために必要
    pm.openPopup();

    // ドラッグ時の連動
    pm.on("dragend", async (e) => {
      const pos = e.target.getLatLng();
      pm.trkpt.lat = pos.lat;
      pm.trkpt.lon = pos.lng;
      if (pm.trkpt.extensions) pm.trkpt.extensions.muniCd5 = null;

      try {
        await geoService.resolveAddress(pm.trkpt);
        markerHistory.save(pm.trkpt);
        dispatchMarkerEvent(MarkerEventTypes.POINT_UPDATED, {
          point: pm.trkpt,
        });
        if (isHistory) pm.setTooltipContent(pm.trkpt.name || "");
      } catch (err) {
        console.error("Address resolution failed on dragend:", err);
      }
    });

    if (isHistory) pm.bindTooltip(trkpt.name || "");

    return pm;
  }

  /**
   * 削除処理
   */
  remove(pm) {
    if (!pm) return;
    if (pm._timer) clearTimeout(pm._timer);
    this.searchMarkers = this.searchMarkers.filter((x) => x !== pm);

    if (this.handler.map && this.handler.map.hasLayer(pm)) {
      this.handler.map.removeLayer(pm);
    }
    this.historyGroup.removeLayer(pm);
  }

  /**
   * 全消去
   */
  clear() {
    this.clearSearchPreviews();
    this.historyGroup.clearLayers();
  }

  clearSearchPreviews() {
    [...this.searchMarkers].forEach((pm) => this.remove(pm));
  }

  _getSearchIcon() {
    return L.divIcon({
      className: "preview-marker",
      html: `<div style="width:24px; height:24px; border-radius:50%; background: rgba(255, 80, 80, 0.8); border: 2px solid #900;"></div>`,
      iconSize: [24, 24],
      iconAnchor: [12, 12],
    });
  }

  _getFootprintIcon() {
    const svgPath = `M12,2c-1.1,0-2,0.9-2,2s0.9,2,2,2s2-0.9,2-2S13.1,2,12,2z M7,7c-1.1,0-2,0.9-2,2s0.9,2,2,2s2-0.9,2-2S8.1,7,7,7z M17,7 c-1.1,0-2,0.9-2,2s0.9,2,2,2s2-0.9,2-2S18.1,7,17,7z M12,8c-2.2,0-4,1.8-4,4c0,1.5,0.8,2.8,2,3.5V18c0,1.1,0.9,2,2,2s2-0.9,2-2v-2.5 c1.2-0.7,2-2,2-3.5C16,9.8,14.2,8,12,8z`;
    return L.divIcon({
      className: "footprint-marker",
      html: `<div style="display:flex;align-items:center;justify-content:center;width:30px;height:30px;"><svg viewBox="0 0 24 24" width="28" height="28"><path d="${svgPath}" fill="#28a745" /></svg></div>`,
      iconSize: [30, 30],
      iconAnchor: [15, 15],
    });
  }
}
