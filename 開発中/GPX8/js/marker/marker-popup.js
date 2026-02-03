import { createPopupContent } from "../components/leaflet-popup.js";
import { notify } from "../api-utils.js";
import { markerEvents, MarkerEventTypes } from "../marker/marker-events.js";
import { geoService } from "../components/geo-service.js";
import { markerHistory } from "../marker/marker-history.js";

export default class MarkerPopup {
  // MarkerPopup.js
  constructor(handler) {
    this.handler = handler;

    markerEvents.addEventListener(MarkerEventTypes.POINT_UPDATED, (e) => {
      const { point } = e.detail;

      // 1. 本マーカー (MarkerHandler)
      const m = this.handler.getMarkerByPoint(point);
      if (m) return this.refresh(m, "marker");

      // 2. しるし (IndicatorManager)
      const ind = this.handler.indicator.indicator;
      if (ind && ind.point === point) return this.refresh(ind, "indicator");

      // 3. プレビュー (MarkerPreview)
      const prev = this.handler.preview.getMarkerByPoint(point);
      if (prev) return this.refresh(prev, "preview");

      // 4. あしあと (MarkerBoundary) ★他と形式が統一されました
//      const hist = this.handler.boundary.getMarkerByPoint(point);
//      if (hist) return this.refresh(hist, "preview");
    });
  }

  bindMarker(m) {
    this.refresh(m, "marker");
  }
  bindIndicator(m) {
    this.refresh(m, "indicator");
  }
  bindPreview(m) {
    this.refresh(m, "preview");
  }

  refresh(marker, type) {
    const content = this.getContent(marker, type);
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

  getContent(marker, type) {
    // 共通のコールバック定義（コピー処理）
    const commonActions = {
      onCopy: (text) => {
        navigator.clipboard.writeText(text);
        notify("📋 座標コピー");
      },
    };

    switch (type) {
      case "marker":
        return this._getMarkerContent(marker, commonActions);
      case "indicator":
        return this._getIndicatorContent(marker, commonActions);
      case "preview":
        // Preview と Boundary(履歴) はここで共通のロジックを使用
        return this._getPreviewContent(marker, commonActions);
      default:
        return null;
    }
  }

  // --- 各種マーカー専用ロジック ---

  _getMarkerContent(marker, common) {
    const entry = this.handler.getEntry(marker);
    if (!entry) return null;
    return createPopupContent(entry.point, marker, {
      ...common,
      onUpdateAddress: () => this.handler.address.updateAddress(entry.point),
      onDelete: () => {
        this.handler.removeMarker(marker);
      },
      onSave: (newData) => this.handler.updatePoint(entry.point, newData),
    });
  }

  _getIndicatorContent(marker, common) {
    return createPopupContent(marker.point, marker, {
      ...common,
      onUpdateAddress: () => this.handler.indicator.updateAddress(),
      onDelete: () => this.handler.indicator.clear(),
      onSave: (newData) => {
        this.handler.addPoint({
          ...marker.point,
          ...newData,
          extensions: { ...marker.point.extensions, keyword: newData.keyword },
        });
        this.handler.indicator.clear();
        notify("✅ 地点を登録しました");
      },
    });
  }

  _getPreviewContent(pm, common) {
    const point = pm.item;
    return createPopupContent(point, pm, {
      ...common,
      onUpdateAddress: async () => {
        try {
          point.desc = null;
          point.extensions.muniCd5 = null;
          await geoService.resolveAddress(point);
          markerHistory.save(point);
          // POINT_UPDATEDを発火して自分自身(リスナー経由)も含め再描画
          markerEvents.dispatchEvent(
            new CustomEvent(MarkerEventTypes.POINT_UPDATED, {
              detail: { point },
            }),
          );
          notify("🔄 住所情報を照会しました");
        } catch (err) {
          notify("❌ 住所照会失敗");
        }
      },
      // 削除ロジック：所属する可能性がある場所すべてから消去を試みる
      onDelete: () => {
        markerHistory.delete(point);
        if (this.handler.preview) this.handler.preview.remove(pm);
        if (this.handler.boundary)
          this.handler.boundary.historyGroup.removeLayer(pm);
        notify("🗑 削除しました");
      },
      onSave: (newData) => {
        Object.assign(point, newData);
        if (newData.extensions) {
          point.extensions = {
            ...(point.extensions || {}),
            ...newData.extensions,
          };
        }
        markerHistory.save(point);
        // 保存後も再描画を依頼
        markerEvents.dispatchEvent(
          new CustomEvent(MarkerEventTypes.POINT_UPDATED, {
            detail: { point },
          }),
        );
        notify("💾 履歴を更新しました");
      },
    });
  }
}
