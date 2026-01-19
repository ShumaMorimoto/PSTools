import { createPopupContent } from "./../components/leaflet-popup.js";
import { geoService } from "./../components/geo-service.js";
import { notify } from "./../api-utils.js";
import {
  markerEvents,
  MarkerEventTypes,
  dispatchMarkerEvent,
} from "../marker/marker-events.js";

export default class MarkerIndicator {
  constructor(handler) {
    this.handler = handler;
    this.map = handler.map;
    this.indicator = null;
    this._isInteractive = true;

    // 🔄 イベント購読：データ更新を検知してポップアップをリフレッシュ
    markerEvents.addEventListener(MarkerEventTypes.POINT_UPDATED, (e) => {
      const { point } = e.detail;
      // 自分の持っているしるしの point と一致する場合のみ更新
      if (this.indicator && this.indicator.point === point) {
        this.refreshPopup();
      }
    });
  }

  init() {
    this.map = this.handler.selector.map;

    // 🔥 Handlerに頼らず、自ら地図クリックを監視する
    this.map.on("click", (e) => {
      // HandlerがIDLE状態のときだけ、クリックされた場所に自分を移動（設置）する
        this.drop(e.latlng);
    });
  }

  /**
   * 状態遷移時に外部から呼ばれる
   * MARKING時は自分を「クリック不可」にして、背後の地図にクリックを流す
   */
  setInteractive(enabled) {
    if (!this.indicator) return;

    // Leafletの内部フラグとDOMの反応を外から強制的に書き換える
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

    const indicatorIcon = L.divIcon({
      className: "ls-indicator-icon",
      html: `<div style="width:20px; height:20px; background:#007BFF; border:2px solid white; border-radius:50% 50% 50% 0; transform:rotate(-45deg); box-shadow:0 2px 5px rgba(0,0,0,0.3);"></div>`,
      iconSize: [20, 20],
      iconAnchor: [10, 20],
    });

    this.indicator = L.marker(latlng, {
      icon: indicatorIcon,
      zIndexOffset: 1000,
      interactive: true
    }).addTo(this.map);

    // 設置した瞬間の状態に合わせてクリック透過を制御
    this.setInteractive(this.handler.state === "idle");

    // 内部データ保持（trkpt形式）
    this.indicator.point = {
      lat: latlng.lat,
      lon: latlng.lng,
      name: "",
      desc: "",
      extensions: {},
    };

    // 設置と同時に住所解決を開始
    this.updateAddress();

    dispatchMarkerEvent(MarkerEventTypes.POINT_SELECTED, this.indicator.point);

    // クリック時はポップアップ表示。イベントを止めてMapClickへの伝搬を防ぐ
    this.indicator.on("click", (e) => {
      L.DomEvent.stopPropagation(e);
      this.refreshPopup();
      this.indicator.openPopup();
    });
  }

  /**
   * ポップアップの表示・更新
   */
  refreshPopup() {
    if (!this.indicator) return;

    const content = createPopupContent(this.indicator.point, this.indicator, {
      onCopy: (text) => {
        navigator.clipboard.writeText(text);
        notify("📋 座標コピー");
      },
      onUpdateAddress: () => this.updateAddress(),
      onSave: (newData) => {
        // 本マーカーへ昇格（Coreを通じて登録）
        this.handler.addPoint({
          ...this.indicator.point,
          name: newData.name,
          desc: newData.desc,
          extensions: {
            ...this.indicator.point.extensions,
            keyword: newData.keyword,
          },
        });
        this.clear();
        notify("✅ 地点を登録しました");
      },
      onDelete: () => this.clear(),
    });

    if (this.indicator.getPopup()) {
      this.indicator.setPopupContent(content);
    } else {
      this.indicator.bindPopup(content, { minWidth: 240, maxWidth: 240 });
    }
  }

  /**
   * 非同期で住所を解決してイベントを通知
   */
  async updateAddress() {
    if (!this.indicator) return;
    const pt = this.indicator.point;

    try {
      // geoService が pt 参照の中身を直接書き換える
      await geoService.resolve(pt);

      // 📣 通知して constructor のリスナー経由で refreshPopup を発動させる
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
