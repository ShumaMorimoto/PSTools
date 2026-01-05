// oore.js

import { callApi } from "/runapp/lib/js/api.js";

export default class MarkerCore {
  constructor(selector, gpxService) {
    this.selector = selector;
    this.gpxService = gpxService;
    this.markers = []; // { m: marker, point: tp, selected: false }
    this._snapshotMarkers = null;
  }

  setModel(initData) {
    this.gpxService.setModel(initData);
    const pts = this.gpxService.getTrkpts();
    pts.forEach((tp) => {
      this.addMarker(tp); // モデル更新なし
    });
    this.selector.updateListUI();
  }

  addMarker(tp) {
    const marker = this._buildMarkerInstance(tp);
    const entry = { m: marker, point: tp, selected: false };
    this.markers.push(entry);
    marker.addTo(this.selector.map);
    this.renumberMarkers();
    return entry;
  }
  addPoint(p) {
    const tp = this.selector.gpxService.appendTrkpt(p);
    const entry = this.addMarker(tp);
    this.selector.updateListUI();
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
    this.selector.updateListUI();
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
      this.selector.map.removeLayer(entry.m);
    });

    this.markers = this.markers.filter((e) => !toRemove.includes(e));

    this.renumberMarkers();
    this.selector.updateListUI();
  }

  // ---------------------------------------------------
  // clearMarkers
  // ---------------------------------------------------
  clearMarkers() {
    const pts = this.gpxService.getTrkpts();
    pts.length = 0;
    this.markers.forEach((entry) => {
      this.selector.map.removeLayer(entry.m);
    });
    this.markers = [];
  }

  async reorderByTSP() {
    const snapshot = this.snapshotMarkers();
    const input = snapshot.map((p) => ({
      lat: p.lat,
      lon: p.lon,
    }));

    const newindices = await callApi("TSPSolver", input);
    console.log("TSPResolver:", newindices);

    this.reorderMarkers(newindices);
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
    this._snapshotMarkers = null;
    this._latestIndices = null;

    this.renumberMarkers();
    this.selector.updateListUI();
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
    this.selector.updateListUI();
  }

  // プレビューモード
  snapshotMarkers() {
    this._snapshotMarkers = [...this.markers]; // markers の順序スナップショット
    this._latestIndices = null; // 最新 index を保持する領域
    return this.gpxService.getTrkpts();
  }
  previewReorder(indices) {
    if (!this.snapshotMarkers) {
      return;
    }
    this._latestIndices = indices; // 最新 index を保持
    this.markers = indices.map((i) => this._snapshotMarkers[i]);
    this.renumberMarkers();
  }
  cancelReorder() {
    const trkpts = this.gpxService.getTrkpts();
    this.markers = trkpts.map((tp) => this.markers.find((x) => x.point === tp));
    this._snapshotMarkers = null;
    this._latestIndices = null;
    this.renumberMarkers();
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

  debugModel() {
    console.log("GPXModel:", this.gpxService.getModel());
  }
}
