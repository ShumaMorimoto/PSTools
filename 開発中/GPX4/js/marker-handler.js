// marker-handler.js
import { fetchAddressAsync } from "./api-utils.js";

export default class MarkerHandler {
  constructor(selector, gpxService) {
    this.selector = selector;
    this.gpxService = gpxService;

    // markers: { m: Leaflet.Marker, selected: boolean }[]
    this.markers = [];
    this.requestSeq = 0;

    this.polyline = L.polyline([], { color: '#ff8800', weight: 3 });
  }

  // ---------------------------------------------------
  // 初期化
  // ---------------------------------------------------
  initMarkers() {
    const pts = this.gpxService.getTrkpts();
    pts.forEach((tp) => {
      this.addPoint(tp); // モデル更新なし
    });
  }

  // ---------------------------------------------------
  // ✅ Selector から呼ばれる共通インターフェース
  // ---------------------------------------------------
  handleMapClick(e) {
    const lat = e.latlng.lat;
    const lng = e.latlng.lng;

    // モデル更新
    const tp = this.gpxService.appendTrkpt({ lat, lon: lng, muitiRoute: "1" });
    // マーカー追加
    this.addPoint(tp);
  }

  // ---------------------------------------------------
  // ポイント追加（クリック/GPXロード共通）
  // ---------------------------------------------------
  addPoint(tp) {
    // 1.1 モデル更新：trkpt 追加（呼び出し側で済んでいる）

    // 1.2 マーカリスト更新：生成 -> 内部配列登録 -> リナンバー
    const marker = this._buildMarkerInstance(tp);
    this.markers.push({ m: marker, point: tp, selected: false });

    // 1.3 地図更新
    marker.addTo(this.selector.map);
    this.renumberMarkers();

    // 1.4 UI更新
    this.selector.uiManager.updateListUI();

    // 1.5 住所情報取得（point 主導）
    if (!tp.extensions && !tp.extended) {
      this.updateAddress(tp);
    }

    // 1.6 ハンドラ登録
    this._bindMarkerHandlers(marker);
    this._updatePolyline();
    this.debugModel();
    return tp;
  }

  // ---------------------------------------------------
  // マーカー生成（生成のみ）
  // ---------------------------------------------------
  _buildMarkerInstance(tp) {
    // 初期アイコン（あとで renumberMarkers で上書きされるが初期値として設定）
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
  // ハンドラ登録（*.6 専用）
  // ---------------------------------------------------
  _bindMarkerHandlers(m) {
    m.on("click", (e) => this.selector.handleMarkerClick(e, m));
    m.on("contextmenu", () => this._onMarkerRightClick(m));
    m.on("dragend", (e) => this._onMarkerDragEnd(e, m));
  }
  // ---------------------------------------------------
  // クリック（選択）
  // ---------------------------------------------------
  handleMarkerClick(e, m) {
    // 2.1 モデル更新：なし（選択状態はモデルに保存しないため）

    // 2.2 マーカリスト更新：選択配列の更新 -> 色の再計算
    const entry = this.markers.find((e) => e.m === m) || null;
    if (!entry) return;

    const isMulti = e.originalEvent.shiftKey || e.originalEvent.ctrlKey;
    if (isMulti) {
      entry.selected = !entry.selected;
    } else {
      this.markers.forEach((x) => (x.selected = false));
      entry.selected = true;
    }
    this.renumberMarkers(); // 色反映

    // 2.3 地図更新：なし（アイコン変更は 2.2 で実施済）

    // 2.4 リスト更新：選択ハイライト反映
    this.selector.uiManager.updateListUI();

    // 2.5 住所情報取得：なし
    // 2.6 ハンドラ登録：済
  }

  // ---------------------------------------------------
  // 右クリック（削除）
  // ---------------------------------------------------
  _onMarkerRightClick(m) {
    this.removeMarker(m);
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
    this.changeState(MarkerHandler.State.IDLE);
  }

  // ---------------------------------------------------
  // ドラッグ終了（位置変更）
  // ---------------------------------------------------
  _onMarkerDragEnd(e, m) {
    const entry = this.markers.find((e) => e.m === m);
    if (!entry) return;

    const latlng = e.target.getLatLng();

    // モデル更新（index 不要）
    entry.point.lat = latlng.lat;
    entry.point.lon = latlng.lng;

    // マーカー更新
    m.setLatLng(latlng);

    this.selector.uiManager.updateListUI();
    this.updateAddress(entry.point);
    this._updatePolyline();
    this.debugModel();
  }

  // ---------------------------------------------------
  // 全マーカー削除（モデル・地図・配列・UI 全同期）
  // ---------------------------------------------------
  clearMarkers() {
    // 1. モデル更新：trkpt 全削除
    const pts = this.gpxService.getTrkpts();
    pts.length = 0; // モデルの唯一の真実をクリア

    // 2. マーカリスト更新：内部配列クリア準備

    // 3. 地図更新：Leaflet レイヤー削除
    this.markers.forEach((entry) => {
      this.selector.map.removeLayer(entry.m);
    });
    this.markers = [];

    // 4. UI 更新：リストを空に
    this.selector.uiManager.updateListUI();
    this._updatePolyline();

    // 5. 住所情報取得：なし（全削除なので）
    // 6. ハンドラ登録：不要（削除済み）

    this.debugModel();
  }
  // ---------------------------------------------------
  // 全ポイントの住所情報を再取得
  // ---------------------------------------------------
  reFetchAllAddresses() {
    const pts = this.gpxService.getTrkpts();

    pts.forEach((tp) => {
      this.updateAddress(tp);
    });

    this.debugModel();
  }

  // ---------------------------------------------------
  // マーカー番号・色の再設定（全件走査）
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

  updateAddress(point) {
    const entry = this.markers.find((e) => e.point === point);
    if (!entry) return;

    const seq = ++this.requestSeq;
    point._reqSeq = seq;

    fetchAddressAsync(point)
      .then((address) => {
        this.applyAddress(point, address, seq);
      })
      .catch((e) => {
        console.warn("住所取得失敗", e);
      });
  }

  applyAddress(point, address, seq) {
    // 追い越し防止
    if (point._reqSeq !== seq) return;

    // point → marker を逆引き
    const entry = this.markers.find((e) => e.point === point);
    if (!entry) return;

    const marker = entry.m;

    // モデル更新
    point.name = address.name || "";
    point.desc = address.display_name || "";
    point.extended = address.address || {};

    // マーカーのポップアップ更新
    try {
      marker.bindPopup(point.name || point.desc).openPopup();
    } catch (e) {}

    // UI 更新
    this.selector.uiManager.updateListUI();
  }

  // ---------------------------------------------------
  // 指定したマーカーへズーム
  // ---------------------------------------------------
  zoomToMarker(marker) {
    if (!marker) return;

    // 現在のズームレベルを維持するか、少し寄るか決められます
    // 例: ズームレベル15で移動
    // this.selector.map.setView(marker.getLatLng(), 15);

    // アニメーション付きで移動する場合 (flyTo)
    // 最大ズームレベルなどを考慮して移動
    this.selector.map.flyTo(marker.getLatLng(), 16, {
      animate: true,
      duration: 1.5, // 秒数
    });

    // 必要ならそのマーカーのポップアップを開く
    marker.openPopup();
  }

  _updatePolyline() {
    const latlngs = this.markers.map((entry) => entry.m.getLatLng());
    this.polyline.setLatLngs(latlngs);

    if (!this.selector.map.hasLayer(this.polyline)) {
      this.polyline.addTo(this.selector.map);
    }
  }

  // ---------------------------------------------------
  // デバッグ
  // ---------------------------------------------------
  debugModel() {
    console.log("GPXModel:", this.gpxService.getModel());
  }
}
