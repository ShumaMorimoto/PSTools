// oore.js

import { callApi } from "/lib/js/api.js";

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
      this.addMarker(tp); // モデル更新なし
    });
    this.handler.selector.updateListUI();
  }

  addMarker(tp) {
    const marker = this._buildMarkerInstance(tp);
    const entry = { m: marker, point: tp, selected: false };
    this.markers.push(entry);
    marker.addTo(this.handler.map);
    this.renumberMarkers();
    return entry;
  }
  addPoint(p) {
    const tp = this.gpxService.appendTrkpt(p);
    const entry = this.addMarker(tp);
    this.handler.selector.updateListUI();
    return entry;
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
    if (tp.name || tp.desc) {
      m.bindPopup(tp.name || tp.desc);
    }
    return m;
  }

  updatePoint(point, info) {
    if (!point || !info) return;
    const entry = this.markers.find((e) => e.point === point);
    if (!entry) return;
    const marker = entry.m;

    // extended だけは個別にマージ
    if (info.extensions && typeof info.extensions === "object") {
      point.extensions = {
        ...(point.extensions || {}),
        ...info.extensions,
      };
    }
    // 残りは普通にマージ
    const { extensions, ...rest } = info;
    Object.assign(point, rest);

    marker.bindPopup(point.name || point.desc).openPopup();
    this.handler.selector.updateListUI();
  }

  // ---------------------------------------------------
  // renumberMarkers
  // ---------------------------------------------------
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

  // ---------------------------------------------------
  // removeMarker
  // ---------------------------------------------------
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
    this.handler.selector.updateListUI();
  }

  // ---------------------------------------------------
  // clearMarkers
  // ---------------------------------------------------
  clearMarkers() {
    const pts = this.gpxService.getTrkpts();
    pts.length = 0;
    this.markers.forEach((entry) => {
      this.handler.map.removeLayer(entry.m);
    });
    this.markers = [];
  }

  async reorderByTSP() {
    // 1. 座標リストを作成
    const input = this.markers.map((e) => ({
      lat: e.point.lat,
      lon: e.point.lon,
    }));

    try {
      // 2. 標準化された callApi を使用
      // ラッピング（{ Places: input }）は不要になり、input をそのまま渡します
      const newindices = await callApi("TSPSolver", input);

      console.log("TSPResolver:", newindices);
      this.reorderMarkers(newindices);
    } catch (error) {
      console.error("TSP Execution failed:", error);
    }
  }

  // ---------------------------------------------------
  // ★ 並び替え適用
  // ---------------------------------------------------
  reorderMarkers(indices) {
    if (!indices || indices.length <= 1) return;

    const trkpts = this.gpxService.getTrkpts();
    const newTrkpts = indices.map((i) => trkpts[i]);
    this.gpxService.setTrkpts(newTrkpts);

    this.markers = newTrkpts.map((tp) =>
      this.markers.find((x) => x.point === tp)
    );

    this.renumberMarkers();
    this.handler.selector.updateListUI();
  }

  jumpMarker(m, n = null) {
    // --- markers から対応する point を取得 ---
    const draggedEntry = this.markers.find((x) => x.m === m);
    if (!draggedEntry) return;

    let targetPos;
    if (n === null) {
      targetPos = 0;
    } else {
      targetPos = this.markers.findIndex((x) => x.m === n);
      if (targetPos === -1) return;
    }

    // --- モデル（trkpts）を並び替える ---
    const draggedTp = draggedEntry.point;
    const trkpts = this.gpxService.getTrkpts();
    const newTrkpts = trkpts.filter((tp) => tp !== draggedTp);
    newTrkpts.splice(targetPos, 0, draggedTp);
    this.gpxService.setTrkpts(newTrkpts);

    // --- markers をモデル順に再構築 ---
    this.markers = newTrkpts.map((tp) =>
      this.markers.find((x) => x.point === tp)
    );

    // --- 表示更新 ---
    this.renumberMarkers();
    this.handler.selector.updateListUI();
  }

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

  /**
   * 指定した座標(latlng)に最も近いマーカーを返す。
   * @param {L.LatLng} latlng - 基準となる座標
   * @param {L.Marker} [excludeMarker] - 検索対象から除外するマーカー（任意）
   */
  getNearestMarker(latlng, excludeMarker = null) {
    const pos = this.handler.map.latLngToContainerPoint(latlng);
    let minDist = Infinity;
    let nearest = null;

    this.markers.forEach((entry) => {
      // 除外対象（ドラッグ中の自分など）がいればスキップ
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
