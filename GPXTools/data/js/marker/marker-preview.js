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
    this.historyGroup = L.layerGroup(); // 自治体履歴用（一括管理）
    this.searchGroup = L.layerGroup(); // 検索結果用（一括管理）

    this.onSelected = this.onSelected.bind(this);

    // データ更新時にポップアップをリフレッシュ
    markerEvents.addEventListener(MarkerEventTypes.POINT_UPDATED, (e) => {
      const { point } = e.detail;
      const pm = this.getMarkerByPoint(point);
      if (pm) this.handler.popup.bindPreview(pm);
    });
  }

  init() {
    this.historyGroup.addTo(this.handler.map);
    this.searchGroup.addTo(this.handler.map);
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
      if (el) el.style.pointerEvents = mode; // 🚩 ここでクリックの可否を強制
      if (!enabled && marker.getPopup()) marker.closePopup();
    });

    // 検索結果側も同様
    this.searchGroup.eachLayer((marker) => {
      marker.options.interactive = enabled;
      const el = marker.getElement();
      if (el) el.style.pointerEvents = mode; // 🚩 ここでクリックの可否を強制
      if (!enabled && marker.getPopup()) marker.closePopup();
    });
  }

  /**
   * 🚩 MarkerBoundary.js から呼ばれる必須メソッド (2/2)
   * 座標(trkpt)に一致するマーカー実体を探して返す
   */
  getMarkerByPoint(point) {
    if (!point) return null;

    // 1. 検索プレビュー配列から探す
    let h = null;
    this.searchGroup.eachLayer((marker) => {
      if (
        marker.trkpt === point ||
        (marker.trkpt.id && marker.trkpt.id === point.id)
      ) {
        h = marker;
      }
    });
    if (h) return h;

    // 2. 履歴グループから探す
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

    // 🚩 最初のコードで成功していた add 直後の制御
    pm.once("add", () => {
      const el = pm.getElement();
      if (el) {
        el.style.pointerEvents = "auto";
        el.style.cursor = "pointer";
      }
    });

    // レイヤーへの追加
    if (isHistory) {
      this.historyGroup.addLayer(pm); // 🚩 ここで実質的に add される
    } else {
      this.searchGroup.addLayer(pm); // 🚩 ここで実質的に add される
      this.handler.map.setView(pm.getLatLng(), 16);
      pm._timer = setTimeout(() => this.remove(pm), 180000);
    }

    // 共通のポップアップ処理
    if (this.handler.popup) {
      this.handler.popup.bindPreview(pm);
    }

    // 履歴マーカーでもクリックでポップアップを出すために必要
    //    pm.openPopup();

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
      } catch (err) {
        console.error("Address resolution failed on dragend:", err);
      }
    });
    return pm;
  }

  /**
   * 削除処理
   */
  remove(pm) {
    if (!pm) return;
    this.searchGroup.removeLayer(pm);
    this.historyGroup.removeLayer(pm);
  }

  /**
   * 全消去
   */
  clear() {
    this.searchGroup.clearLayers();
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
    // 🚩 旗（Flag）のSVGパス
    const svgPath = `M14.4,6L14,4H5V21H7V14H12.6L13,16H20V6H14.4Z`;

    return L.divIcon({
      className: "flag-marker", // クラス名も変更可能
      html: `
        <div style="display:flex; align-items:center; justify-content:center; width:30px; height:30px;">
          <svg viewBox="0 0 24 24" width="28" height="28" style="filter: drop-shadow(0 0 1.5px #fff) drop-shadow(0 0 1.5px #fff);">
            <path d="${svgPath}" fill="#f31212" />
          </svg>
        </div>`,
      iconSize: [30, 30],
      iconAnchor: [7, 21], // 🚩 旗のポールの下端（左下付近）を基準点に設定
    });
  }
}
