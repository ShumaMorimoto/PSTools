// marker/marker-core.js
import { callApi } from "/lib/js/api.js";
import { dispatchMarkerEvent, MarkerEventTypes } from "./marker-events.js";

export default class MarkerCore {
  constructor(handler) {
    this.handler = handler;
    this.gpxService = handler.gpxService;
    this.markers = []; // { m: marker, point: tp, selected: false }
    this._snapshotMarkers = null;
  }

  setModel(initData) {
    this.gpxService.setModel(initData);
    const pts = this.gpxService.getTrkpts();
    pts.forEach((tp) => {
      this.addMarker(tp, false); // 個別通知を抑制して追加
    });
    // 全体セット完了の通知
    dispatchMarkerEvent(MarkerEventTypes.LIST_CHANGED);
  }

  /**
   * マーカーインスタンスを生成してリストに追加
   * @param {object} tp - トラックポイントデータ
   * @param {boolean} notify - イベントを通知するかどうか
   */
  addMarker(tp, notify = true) {
    const marker = this._buildMarkerInstance(tp);
    const entry = { m: marker, point: tp, selected: false };
    this.markers.push(entry);
    marker.addTo(this.handler.map);
    this.renumberMarkers();

    if (notify) {
      dispatchMarkerEvent(MarkerEventTypes.LIST_CHANGED);
    }
    return entry;
  }

  addPoint(p) {
    const tp = this.gpxService.appendTrkpt(p);
    const entry = this.addMarker(tp, true);
    return entry;
  }

  /**
   * 複数のポイントを一括で追加する
   * @param {Array} points - 追加するポイントデータの配列
   */
  addPoints(points) {
    if (!Array.isArray(points) || points.length === 0) return [];

    const entries = [];
    points.forEach((p) => {
      // 1. GPXモデルに追加
      const tp = this.gpxService.appendTrkpt(p);
      // 2. マーカー生成と内部リストへの追加 (通知は抑制)
      const entry = this.addMarker(tp, false);
      entries.push(entry);
    });
    // 3. すべての追加が終わってから「1回だけ」通知
    dispatchMarkerEvent(MarkerEventTypes.LIST_CHANGED);
    return entries;
  }

  _buildMarkerInstance(tp) {
    const icon = L.ExtraMarkers.icon({
      icon: "fa-number",
      number: 0,
      markerColor: "blue",
      shape: "circle",
    });
    const m = L.marker([tp.lat, tp.lon], {
      draggable: true,
      icon: icon,
    });
    // ポップアップのバインド（初期表示用）
    if (tp.name || tp.desc) {
      m.bindPopup(tp.name || tp.desc);
    }
    return m;
  }

  updatePoint(point, info) {
    if (!point || !info) return;
    const entry = this.markers.find((e) => e.point === point);
    if (!entry) return;

    // extensions のマージ
    if (info.extensions && typeof info.extensions === "object") {
      point.extensions = {
        ...(point.extensions || {}),
        ...info.extensions,
      };
    }
    // その他のプロパティのマージ
    const { extensions, ...rest } = info;
    Object.assign(point, rest);

    // 通知を発火（MarkerHandlerやPopupがこれを受けて表示を更新する）
    dispatchMarkerEvent(MarkerEventTypes.POINT_UPDATED, {
      point: point,
      marker: entry.m,
      info: info,
    });
  }

  renumberMarkers() {
    this.markers.forEach((entry, i) => {
      const icon = L.ExtraMarkers.icon({
        icon: "fa-number",
        number: i + 1,
        markerColor: entry.selected ? "red" : "blue",
        shape: "circle",
      });
      entry.m.setIcon(icon);
    });
  }

  removeMarker(m, split = false) {
    const idx = this.markers.findIndex((e) => e.m === m);
    if (idx === -1) return;

    const toRemove = split
      ? this.markers.slice(0, idx + 1)
      : this.markers.slice(idx, idx + 1);

    toRemove.forEach((entry) => {
      this.gpxService.removeTrkpt(entry.point);
      this.handler.map.removeLayer(entry.m);
    });

    this.markers = this.markers.filter((e) => !toRemove.includes(e));

    this.renumberMarkers();
    dispatchMarkerEvent(MarkerEventTypes.LIST_CHANGED);
  }

  clearMarkers() {
    const pts = this.gpxService.getTrkpts();
    pts.length = 0;
    this.markers.forEach((entry) => {
      this.handler.map.removeLayer(entry.m);
    });
    this.markers = [];
    dispatchMarkerEvent(MarkerEventTypes.LIST_CHANGED);
  }

  async reorderByTSP() {
    const input = this.markers.map((e) => ({
      lat: e.point.lat,
      lon: e.point.lon,
    }));

    try {
      const newindices = await callApi("TSPSolver", input);
      console.log("TSPResolver:", newindices);
      this.reorderMarkers(newindices);
    } catch (error) {
      console.error("TSP Execution failed:", error);
    }
  }

  reorderMarkers(indices) {
    if (!indices || indices.length <= 1) return;

    const trkpts = this.gpxService.getTrkpts();
    const newTrkpts = indices.map((i) => trkpts[i]);
    this.gpxService.setTrkpts(newTrkpts);

    this.markers = newTrkpts.map((tp) =>
      this.markers.find((x) => x.point === tp)
    );

    this.renumberMarkers();
    dispatchMarkerEvent(MarkerEventTypes.LIST_CHANGED);
  }

  jumpMarker(m, n = null) {
    const draggedEntry = this.markers.find((x) => x.m === m);
    if (!draggedEntry) return;

    let targetPos;
    if (n === null) {
      targetPos = 0;
    } else {
      targetPos = this.markers.findIndex((x) => x.m === n);
      if (targetPos === -1) return;
    }

    const draggedTp = draggedEntry.point;
    const trkpts = this.gpxService.getTrkpts();
    const newTrkpts = trkpts.filter((tp) => tp !== draggedTp);
    newTrkpts.splice(targetPos, 0, draggedTp);
    this.gpxService.setTrkpts(newTrkpts);

    this.markers = newTrkpts.map((tp) =>
      this.markers.find((x) => x.point === tp)
    );

    this.renumberMarkers();
    dispatchMarkerEvent(MarkerEventTypes.LIST_CHANGED);
  }

  // Getter系は変更なし
  getMarkers() {
    return this.markers;
  }
  getMarker(index) {
    return this.markers[index].m;
  }
  getPoints() {
    return this.gpxService.getTrkpts();
  }
  getPoint(index) {
    return this.gpxService.getTrkpts()[index];
  }
  getEntry(marker) {
    return this.markers.find((x) => x.m === marker);
  }
  getMarkerByPoint(point) {
    // 配列 this.markers から、point が一致する要素を探し、そのマーカー(m)を返す
    const entry = this.markers.find((x) => x.point === point);
    return entry ? entry.m : null;
  }

  getNearestMarker(latlng, excludeMarker = null) {
    const pos = this.handler.map.latLngToContainerPoint(latlng);
    let minDist = Infinity;
    let nearest = null;

    this.markers.forEach((entry) => {
      if (excludeMarker && entry.m === excludeMarker) return;
      const p = this.handler.map.latLngToContainerPoint(entry.m.getLatLng());
      const d = pos.distanceTo(p);
      if (d < minDist) {
        minDist = d;
        nearest = { marker: entry.m, dist: d };
      }
    });
    return nearest;
  }

  debugModel() {
    console.log("GPXModel:", this.gpxService.getModel());
  }
}
