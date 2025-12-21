// marker-handler.js

export default class MarkerHandler {
  constructor(selector, gpxService) {
    this.selector = selector;
    this.gpxService = gpxService;

    // markers: { m: Leaflet.Marker, selected: boolean }[]
    this.markers = [];
    this.requestSeq = 0;
  }

  // ---------------------------------------------------
  // 初期化
  // ---------------------------------------------------
  initMarkers() {
    const pts = this.gpxService.getTrkptList();
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
    const tp = this.gpxService.addTrkpt({ lat, lon: lng });
    // マーカー追加
    this.addPoint(tp);
  }

  // ---------------------------------------------------
  // ポイント追加（クリック/GPXロード共通）
  // ---------------------------------------------------
  addPoint(tp) {
    // 1.1 モデル更新：trkpt 追加（データ確定）
    //    const tp = this.gpxService.addTrkpt(info);
    // 呼び出し側に委譲

    // 1.2 マーカリスト更新：生成 -> 内部配列登録 -> リナンバー(アイコン決定)
    const idx = this.markers.length;
    const marker = this._buildMarkerInstance(tp, idx); // 生成
    this.markers.push({ m: marker, selected: false });
    this.renumberMarkers(); // 番号・色確定

    // 1.3 地図更新：Layer追加
    marker.addTo(this.selector.map);

    // 1.4 リスト更新：UI反映
    this.selector.uiManager.updateListUI();

    // 1.5 住所情報取得（非同期）
    if (!tp.extensions && !tp.extended) {
      this.selector.fetchAddressAsync(tp, marker, this);
    }

    // 1.6 ハンドラ登録
    this._bindMarkerHandlers(marker);

    this.debugModel();
    return tp;
  }

  // ---------------------------------------------------
  // マーカー生成（生成のみ）
  // ---------------------------------------------------
  _buildMarkerInstance(tp, idx) {
    // 初期アイコン（あとで renumberMarkers で上書きされるが初期値として設定）
    const icon = L.ExtraMarkers.icon({
      icon: "fa-number",
      number: idx + 1,
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
    m.on("click", (e) => this._onMarkerClick(e, m));
    m.on("contextmenu", () => this._onMarkerRightClick(m));
    m.on("dragend", (e) => this._onMarkerDragEnd(e, m));
  }

  // ---------------------------------------------------
  // クリック（選択）
  // ---------------------------------------------------
  _onMarkerClick(e, m) {
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
    const idx = this.markers.findIndex((e) => e.m === m);
    if (idx === -1) return;

    // 3.1 モデル更新：trkpt 削除
    this.gpxService.removeTrkpt(idx);

    // 3.2 マーカリスト更新：内部配列から削除・選択配列から除外 -> 番号振り直し
    this.markers.splice(idx, 1);
    this.renumberMarkers();

    // 3.3 地図更新：Layer削除
    this.selector.map.removeLayer(m);

    // 3.4 リスト更新：行削除
    this.selector.uiManager.updateListUI();

    // 3.5 住所情報取得：なし
    // 3.6 ハンドラ登録：不要（削除済み）

    this.debugModel();
  }

  // ---------------------------------------------------
  // ドラッグ終了（位置変更）
  // ---------------------------------------------------
  _onMarkerDragEnd(e, m) {
    const idx = this.markers.indexOf(m);
    if (idx === -1) return;
    const latlng = e.target.getLatLng();

    // 4.1 モデル更新：座標更新
    this.gpxService.updateTrkpt(idx, {
      lat: latlng.lat,
      lon: latlng.lng,
    });

    // 4.2 マーカリスト更新：内部整合性確認 -> (必要ならリナンバー)
    // ※順序が変わるわけではないのでリナンバーは必須ではないが、
    //   念のため全体整合性を取るなら呼んでも良い。今回は呼ぶ。
    this.renumberMarkers();

    // 4.3 地図更新：位置同期 (Leafletが自動でやってくれるが明示的に書くなら setLatLng)
    m.setLatLng(latlng);

    // 4.4 リスト更新：座標表示の更新
    this.selector.uiManager.updateListUI();

    // 4.5 住所情報取得（非同期）：新座標で再取得
    const tp = this.gpxService.getTrkptList()[idx];
    this.selector.fetchAddressAsync(tp, m, this);

    // 4.6 ハンドラ登録：済

    this.debugModel();
  }

  // ---------------------------------------------------
  // 全マーカー削除（モデル・地図・配列・UI 全同期）
  // ---------------------------------------------------
  clearMarkers() {
    // 1. モデル更新：trkpt 全削除
    const pts = this.gpxService.getTrkptList();
    pts.length = 0; // モデルの唯一の真実をクリア

    // 2. マーカリスト更新：内部配列クリア準備

    // 3. 地図更新：Leaflet レイヤー削除
    this.markers.forEach((entry) => {
      this.selector.map.removeLayer(entry.m);
    });
    this.markers = [];

    // 4. UI 更新：リストを空に
    this.selector.uiManager.updateListUI();

    // 5. 住所情報取得：なし（全削除なので）
    // 6. ハンドラ登録：不要（削除済み）

    this.debugModel();
  }
  // ---------------------------------------------------
  // 全ポイントの住所情報を再取得
  // ---------------------------------------------------
  reFetchAllAddresses() {
    // 5. 住所情報取得（非同期）：全ポイントで再取得
    const pts = this.gpxService.getTrkptList();

    pts.forEach((tp, idx) => {
      const entry = this.markers[idx];
      if (!entry) return;
      const marker = entry.m;
      this.selector.fetchAddressAsync(tp, marker, this);
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

  // ---------------------------------------------------
  // デバッグ
  // ---------------------------------------------------
  debugModel() {
    console.log("GPXModel:", this.gpxService.getModel());
  }
}
