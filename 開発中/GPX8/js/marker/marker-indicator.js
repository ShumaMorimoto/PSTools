import { createPopupContent } from "./../components/leaflet-popup.js";
import { geoService } from "./../components/geo-service.js";
import { notify } from "./../api-utils.js";

export default class MarkerIndicator {
  constructor(handler) {
    this.handler = handler;
    this.map = handler.map;
    this.indicator = null;
  }

  /**
   * 地図クリック時に呼ばれる：しるしを設置
   */
  drop(latlng) {
    this.clear();

    // 1. アイコン定義（青いドロップ型）
    const indicatorIcon = L.divIcon({
      className: "ls-indicator-icon",
      html: `<div style="width:20px; height:20px; background:#007BFF; border:2px solid white; border-radius:50% 50% 50% 0; transform:rotate(-45deg); box-shadow:0 2px 5px rgba(0,0,0,0.3);"></div>`,
      iconSize: [20, 20],
      iconAnchor: [10, 20],
    });

    // 2. マーカー設置
    this.indicator = L.marker(latlng, {
      icon: indicatorIcon,
      zIndexOffset: 1000,
    }).addTo(this.map);

    // 3. 内部データ保持（trkpt形式）
    this.indicator.point = {
      lat: latlng.lat,
      lon: latlng.lng,
      name: "新規地点",
      desc: "住所を取得中...",
      extensions: {}
    };

    // 4. イベント登録
    this.indicator.on("click", () => {
      this.refreshPopup();
      this.updateAddress();
    });
  }

  /**
   * ポップアップの表示・更新（MarkerPreview.refreshPopup と同様）
   */
  refreshPopup() {
    if (!this.indicator) return;

    const content = createPopupContent(this.indicator.point, this.indicator, {
      onCopy: (text) => {
        navigator.clipboard.writeText(text);
        notify("📋 座標コピー");
      },

      // 🔄 住所の再取得
      onUpdateAddress: () => this.updateAddress(),

      // 💾 保存（本マーカーへ昇格）
      onSave: (newData) => {
        this.handler.addPoint({
          ...this.indicator.point,
          name: newData.name,
          desc: newData.desc,
          extensions: { ...this.indicator.point.extensions, keyword: newData.keyword }
        });
        this.clear();
        notify("✅ 地点を登録しました");
      },

      onDelete: () => this.clear()
    });

    if (this.indicator.getPopup()) {
      this.indicator.setPopupContent(content);
    } else {
      this.indicator.bindPopup(content, { minWidth: 240, maxWidth: 240 }).openPopup();
    }
  }

  /**
   * 非同期で住所を解決して表示を更新
   */
  async updateAddress() {
    if (!this.indicator) return;
    const pt = this.indicator.point;

    try {
      // Nominatim と 国土地理院の両方から取得
      const [addressData, resolvedPoint] = await Promise.all([
        geoService.resolveAddress(pt),
        geoService.resolve(pt)
      ]);

      // データのマージ（参照を書き換える）
      pt.name = addressData.name || resolvedPoint.name || pt.name;
      pt.desc = resolvedPoint.desc || pt.desc;
      pt.extensions = {
        ...(resolvedPoint.extensions || {}),
        ...(addressData.address || {}),
      };

      // UIに反映
      this.refreshPopup();
    } catch (e) {
      console.warn("しるしの住所解決に失敗:", e);
      pt.desc = "住所を取得できませんでした";
      this.refreshPopup();
    }
  }

  clear() {
    if (this.indicator) {
      this.map.removeLayer(this.indicator);
      this.indicator = null;
    }
  }
}