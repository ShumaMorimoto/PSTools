<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Leaflet 画像重ね合わせ＆座標取得ツール</title>
    
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" integrity="sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY=" crossorigin=""/>
    <link rel="stylesheet" href="https://unpkg.com/leaflet-distortableimage@latest/dist/leaflet.distortableimage.css" media="screen" title="no title">
    <link rel="stylesheet" href="https://use.fontawesome.com/releases/v5.8.1/css/all.css">

    <style>
        body { margin: 0; padding: 0; display: flex; flex-direction: column; height: 100vh; font-family: sans-serif; }
        
        #controls {
            padding: 10px; background: #f8f9fa; border-bottom: 1px solid #ddd;
            display: flex; align-items: center; gap: 15px; flex-wrap: wrap; z-index: 1000;
        }
        
        #map { flex-grow: 1; width: 100%; cursor: crosshair; }

        .btn {
            padding: 8px 16px; background-color: #007bff; color: white;
            border: none; border-radius: 4px; cursor: pointer; font-size: 14px;
            display: inline-flex; align-items: center; gap: 5px;
        }
        .btn:hover { background-color: #0056b3; }
        
        .btn.locked { background-color: #dc3545; }
        .btn.locked:hover { background-color: #c82333; }

        input[type="file"] { display: none; }
        
        #info-box {
            font-family: monospace; font-size: 14px;
            background: white; padding: 5px 10px; border: 1px solid #ccc; border-radius: 4px;
        }

        /* --- ロックモード時のスタイル制御 --- */
        /* ロック時は画像レイヤーへのマウスイベントを遮断（地図クリックを優先） */
        .map-locked .leaflet-distortable-image-overlay,
        .map-locked img.leaflet-image-layer {
            pointer-events: none !important; 
            cursor: crosshair !important;
            opacity: 0.8 !important; 
            z-index: 200 !important; 
        }
    </style>
</head>

<body>

<div id="controls">
    <label for="imageInput" class="btn">
        <i class="fas fa-upload"></i> 画像を追加
    </label>
    <input type="file" id="imageInput" accept="image/*">

    <button id="toggleLockBtn" class="btn" onclick="toggleLockMode()">
        <i class="fas fa-lock-open"></i> <span>位置調整モード</span>
    </button>

    <div id="info-box">座標: <span id="coords">マップをクリックしてください</span></div>
</div>

<div id="map"></div>

    <!-- ライブラリ読み込み -->
    <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js" integrity="sha256-20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV1lvTlZBo=" crossorigin=""></script>
    <script src="https://unpkg.com/leaflet-toolbar@0.4.0-alpha.2/dist/leaflet.toolbar.js"></script>
    <script src="https://unpkg.com/leaflet-distortableimage@latest/dist/leaflet.distortableimage.js"></script>

    <script>
        // --- 1. 地図の初期化 ---
        const map = L.map('map').setView([35.681236, 139.767125], 15);
        L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
            maxZoom: 19,
            attribution: '&copy; OpenStreetMap'
        }).addTo(map);

        // --- 2. 画像管理 (重要: distortableCollectionを使用) ---
        // ここをFeatureGroupにしてしまうとエラーになります。正常版と同じCollectionを使います。
        let imgGroup = L.distortableCollection().addTo(map);
        
        let isLocked = false; 

        // --- 3. 画像追加関数 ---
        function addImageToMap(url) {
            if (isLocked) {
                alert("画像を編集するには「確定済」を解除して「位置調整モード」にしてください。");
                return;
            }

            const bounds = map.getBounds();
            const center = bounds.getCenter();
            
            // 画面の70%サイズに計算
            const height = (bounds.getNorth() - bounds.getSouth()) * 0.7;
            const width = (bounds.getEast() - bounds.getWest()) * 0.7;

            const north = center.lat + height / 2;
            const south = center.lat - height / 2;
            const west = center.lng - width / 2;
            const east = center.lng + width / 2;

            const initialCorners = [
                L.latLng(north, west), L.latLng(north, east),
                L.latLng(south, west), L.latLng(south, east)
            ];

            // 画像生成
            const img = L.distortableImageOverlay(url, {
                actions: [L.RotateAction, L.ScaleAction, L.FreeRotateAction, L.LockAction, L.OpacityAction, L.DeleteAction],
                corners: initialCorners,
                selected: true // 初期状態で選択済みにする
            });

            // ★重要: FeatureGroupではなく、Collectionに追加する
            imgGroup.addLayer(img);
        }

        // --- 4. 確定/編集モード切り替え ---
        function toggleLockMode() {
            isLocked = !isLocked;
            const btn = document.getElementById('toggleLockBtn');
            const mapDiv = document.getElementById('map');

            if (isLocked) {
                // === [ロックモード ON] ===
                btn.innerHTML = '<i class="fas fa-lock"></i> <span>確定済 (クリックで座標取得)</span>';
                btn.classList.add('locked');
                mapDiv.classList.add('map-locked');

                // 全ての画像の編集を無効化し、選択を解除
                imgGroup.eachLayer(function(layer) {
                    layer.editing.disable();
                    layer.deselect();
                });

            } else {
                // === [ロックモード OFF] ===
                btn.innerHTML = '<i class="fas fa-lock-open"></i> <span>位置調整モード</span>';
                btn.classList.remove('locked');
                mapDiv.classList.remove('map-locked');

                // 編集機能を有効化 (選択はユーザーに任せるか、必要ならここでselectする)
                imgGroup.eachLayer(function(layer) {
                    layer.editing.enable();
                });
            }
        }

        // --- 5. 地図クリックイベント ---
        map.on('click', function(e) {
            // ロックモード時は画像がクリック透過(pointer-events:none)になるため
            // 画像の上をクリックしても、地図のクリックイベントが発火します。
            const lat = e.latlng.lat.toFixed(6);
            const lng = e.latlng.lng.toFixed(6);

            document.getElementById('coords').innerText = `${lat}, ${lng}`;

            L.popup()
                .setLatLng(e.latlng)
                .setContent(`<strong>取得座標:</strong><br>${lat}, ${lng}`)
                .openOn(map);
        });

        // --- 6. ファイル読み込みイベント ---
        document.getElementById('imageInput').addEventListener('change', function(e) {
            const file = e.target.files[0];
            if (!file) return;
            const reader = new FileReader();
            reader.onload = function(event) { addImageToMap(event.target.result); e.target.value = ''; };
            reader.readAsDataURL(file);
        });

        // ドラッグ＆ドロップ対応
        const mapArea = document.getElementById('map');
        mapArea.addEventListener('dragover', (e) => { e.preventDefault(); });
        mapArea.addEventListener('drop', (e) => {
            e.preventDefault();
            const file = e.dataTransfer.files[0];
            if (file && file.type.startsWith('image/')) {
                const reader = new FileReader();
                reader.onload = function(event) { addImageToMap(event.target.result); };
                reader.readAsDataURL(file);
            }
        });
    </script>
</body>
</html>
