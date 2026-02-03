import { geoService } from "./../components/geo-service.js";
import {
  markerEvents,
  MarkerEventTypes,
  dispatchMarkerEvent,
} from "../marker/marker-events.js";
import { callApi } from "/lib/js/api.js";

export default class MarkerIndicator {
  constructor(handler) {
    this.handler = handler;
    this.map = handler.map;
    this.indicator = null;
    this._isInteractive = true;

    // 🔄 イベント購読：データ更新を検知してポップアップをリフレッシュ
    markerEvents.addEventListener(MarkerEventTypes.POINT_UPDATED, (e) => {
      const { point } = e.detail;
      if (this.indicator && this.indicator.point === point) {
        // 自前のロジックではなく、集約されたPopupクラスにリフレッシュを任せる
        this.handler.popup.bindIndicator(this.indicator);
      }
    });
  }

  init() {
    this.map = this.handler.selector.map;
    this.map.on("click", (e) => {
      this.drop(e.latlng);
    });
  }

  setInteractive(enabled) {
    if (!this.indicator) return;
    this.indicator.options.interactive = enabled;
    const el = this.indicator.getElement();
    if (el) {
      el.style.pointerEvents = enabled ? "auto" : "none";
    }
  }

  /**
   * 地図クリック時に呼ばれる：しるしを設置
   */
  drop(latlng) {
    this.clear();

    this.map.setView(latlng, this.map.getZoom());

    const indicatorIcon = L.divIcon({
      className: "ls-indicator-icon",
      html: `<div style="width:20px; height:20px; background:#007BFF; border:2px solid white; border-radius:50% 50% 50% 0; transform:rotate(-45deg); box-shadow:0 2px 5px rgba(0,0,0,0.3);"></div>`,
      iconSize: [20, 20],
      iconAnchor: [10, 20],
    });

    this.indicator = L.marker(latlng, {
      icon: indicatorIcon,
      zIndexOffset: 1000,
      interactive: true,
    }).addTo(this.map);

    // 【重要】先にデータをセット（これを bind より先にしないと Popup 側でエラーになる）
    this.indicator.point = {
      lat: latlng.lat,
      lon: latlng.lon || latlng.lng,
      name: "",
      desc: "",
      extensions: {},
    };

    // 設置した瞬間の状態に合わせてクリック透過を制御
    this.setInteractive(this.handler.state === "idle");

    // --- ここで集約クラスにバインドを委譲 ---
    this.handler.menu.bindIndicator(this.indicator);
    this.handler.popup.bindIndicator(this.indicator);

    // 設置と同時に住所解決を開始
    this.updateAddress();

    dispatchMarkerEvent(MarkerEventTypes.POINT_SELECTED, this.indicator.point);

    this.indicator.on("click", (e) => {
      L.DomEvent.stopPropagation(e);
      // Popup 側が最新状態を維持しているため、開くだけでOK
      this.indicator.openPopup();
    });
  }

  async sendLocation() {
    if (!navigator.geolocation) {
      alert("GPSがサポートされていません");
      return;
    }
    navigator.geolocation.getCurrentPosition(
      async (pos) => {
        try {
          const input = {
            lat: pos.coords.latitude,
            lon: pos.coords.longitude,
          };
          await callApi("SendLocation", input);
        } catch (e) {
          console.error(e);
        }
      },
      (err) => {
        alert("GPSエラー: " + err.message);
      },
    );
  }

  async getLocation() {
    try {
      const latlng = await callApi("GetLocation");
      if (latlng.lat && latlng.lon) {
        this.drop(latlng);
      }
    } catch (e) {
      console.error("同期失敗", e);
    }
  }

  /**
   * 非同期で住所を解決してイベントを通知
   */
  async updateAddress() {
    if (!this.indicator) return;
    const pt = this.indicator.point;

    try {
      await geoService.resolve(pt);
      dispatchMarkerEvent(MarkerEventTypes.POINT_UPDATED, { point: pt });
    } catch (e) {
      console.warn("しるしの住所解決に失敗:", e);
      pt.desc = "住所を取得できませんでした";
      dispatchMarkerEvent(MarkerEventTypes.POINT_UPDATED, { point: pt });
    }
  }

  clear() {
    if (this.indicator) {
      this.map.removeLayer(this.indicator);
      this.indicator = null;
    }
  }
}
