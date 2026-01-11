import { createPopupContent } from "../components/leaflet-popup.js";
import { notify } from "../api-utils.js";
import { markerEvents, MarkerEventTypes } from "../marker/marker-events.js";

export default class MarkerPopup {
  constructor(handler) {
    this.handler = handler;

    // モデル更新イベントの購読
    markerEvents.addEventListener(MarkerEventTypes.POINT_UPDATED, (e) => {
      const { point } = e.detail;
      const marker = this.handler.getMarkerByPoint(point);
      if (marker) {
        this.refresh(marker);
      }
    });
  }

  bindMarker(marker) {
    this.refresh(marker);
  }

  refresh(marker) {
    const content = this.getContent(marker);
    if (!content) return;

    if (marker.getPopup()) {
      marker.setPopupContent(content);
    } else {
      marker.bindPopup(content, {
        minWidth: 240,
        maxWidth: 240,
        autoPan: true,
      });
    }
  }

  getContent(marker) {
    const entry = this.handler.getEntry(marker);
    if (!entry) return null;

    return createPopupContent(entry.point, marker, {
      onCopy: (text) => {
        navigator.clipboard.writeText(text);
        notify("📋 座標をコピーしました");
      },
      onUpdateAddress: async () => {
        await this.handler.address.updateAddress(entry.point);
      },
      onDelete: () => {
        if (confirm('削除しますか？')) this.handler.removeMarker(marker);
      },
      onSave: async (newData) => {
        await this.handler.updatePoint(entry.point, {
          name: newData.name,
          desc: newData.desc,
          extensions: { ...entry.point.extensions, keyword: newData.keyword },
        });
        notify("✅ 保存しました");
      },
    });
  }
}