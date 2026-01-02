// oore.js

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
    this.selector.updateList();
  }

  addMarker(tp) {
    const marker = this._buildMarkerInstance(tp);
    this.markers.push({ m: marker, point: tp, selected: false });
    marker.addTo(this.selector.map);
    this.renumberMarkers();
    return marker;
  }
  addPoint(p) {
    const tp = this.selector.gpxService.appendTrkpt(p);
    const marker = this.addMarker(tp);
    this.selector.updateList();
    return marker;
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
    this.selector.updateList();
  }

  // ---------------------------------------------------
  // ★ 並び替え適用
  // ---------------------------------------------------
  reorderMarkers(indices) {
    const trkpts = this.gpxService.getTrkpts();
    const newTrkpts = indices.map((i) => trkpts[i]);
    this.gpxService.setTrkpts(newTrkpts);

    this.markers = newTrkpts.map((tp) =>
      this.markers.find((x) => x.point === tp)
    );
    this._snapshotMarkers = null;
    this._latestIndices = null;

    this.renumberMarkers();
    this.selector.updateList();
  }

  jumpMarker(m, n) {
    // --- markers から対応する point を取得 ---
    const draggedEntry = this.markers.find((x) => x.m === m);
    const targetEntry = this.markers.find((x) => x.m === n);
    if (!draggedEntry || !targetEntry) return;

    const draggedTp = draggedEntry.point;
    const targetTp = targetEntry.point;

    // --- モデル（trkpts）を並び替える ---
    const trkpts = this.gpxService.getTrkpts();
    const newTrkpts = trkpts.filter((tp) => tp !== draggedTp);
    const targetPos = newTrkpts.indexOf(targetTp);
    newTrkpts.splice(targetPos + 1, 0, draggedTp);
    this.gpxService.setTrkpts(newTrkpts);

    // --- markers をモデル順に再構築 ---
    this.markers = newTrkpts.map((tp) =>
      this.markers.find((x) => x.point === tp)
    );

    // --- 表示更新 ---
    this.renumberMarkers();
    this.selector.updateList();
  }

  // プレビューモード
  snapshotMarkers() {
    this._snapshotMarkers = [...this.markers]; // markers の順序スナップショット
    this._latestIndices = null; // 最新 index を保持する領域
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

  // 選択関連メソッド（handleMarkerClickから移行）
  toggleSelection(entry, isMulti) {
    // 選択/非選択のロジック
    // ...
    this.renumberMarkers();
  }

  clearMarkers() {
    // 既存のclearMarkersロジックをコピー
    // ...
  }
}
