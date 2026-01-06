<!DOCTYPE html>
<html lang="ja">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Leaflet Search Component (Custom Action)</title>
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />

    <style>
        body {
            margin: 0;
            padding: 0;
            font-family: sans-serif;
        }

        #map {
            height: 100vh;
            width: 100%;
        }

        /* コンポーネント用スタイル */
        .leaflet-search-control {
            background: white;
            border-radius: 4px;
            box-shadow: 0 1px 5px rgba(0, 0, 0, 0.4);
            padding: 10px;
            width: 300px;
            font-family: sans-serif;
        }

        .leaflet-search-input {
            width: 100%;
            padding: 8px;
            box-sizing: border-box;
            border: 1px solid #ccc;
            border-radius: 4px;
            font-size: 14px;
        }

        .leaflet-search-suggestions {
            list-style: none;
            margin: 5px 0 0 0;
            padding: 0;
            border: 1px solid #eee;
            border-top: none;
            max-height: 200px;
            overflow-y: auto;
            background: white;
            display: none;
        }

        .leaflet-search-suggestions li {
            padding: 8px;
            cursor: pointer;
            border-bottom: 1px solid #eee;
            font-size: 13px;
            display: flex;
            align-items: center;
        }

        .leaflet-search-suggestions li:hover {
            background-color: #f8f9fa;
        }

        .ls-badge {
            font-size: 10px;
            padding: 2px 5px;
            border-radius: 3px;
            margin-right: 8px;
            color: white;
            min-width: 30px;
            text-align: center;
        }

        .ls-badge-history {
            background-color: #28a745;
        }

        .ls-badge-web {
            background-color: #007bff;
        }
    </style>
</head>

<body>

    <div id="map"></div>

    <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>

    <script>
        // ----------------------------------------------------------------------
        // 検索コンポーネント定義 (L.Control.SearchWithHistory)
        // ----------------------------------------------------------------------
        L.Control.SearchWithHistory = L.Control.extend({
            options: {
                position: 'topleft',
                placeholder: '場所を検索...',
                maxHistory: 20,
                historyKey: 'leaflet_search_history',
                nominatimUrl: 'https://nominatim.openstreetmap.org/search',
                autoCollapse: true,

                // ★ デフォルトのアクション (外部から上書き可能)
                onLocationSelected: function (item, map, control) {
                    // デフォルト動作：ズーム移動
                    map.setView([item.lat, item.lng], 16);

                    // デフォルト動作：マーカー表示（control内で管理しているマーカーがあれば消す）
                    if (control._currentMarker) {
                        map.removeLayer(control._currentMarker);
                    }
                    control._currentMarker = L.marker([item.lat, item.lng])
                        .addTo(map)
                        .bindPopup(item.name)
                        .openPopup();
                }
            },

            onAdd: function (map) {
                const container = L.DomUtil.create('div', 'leaflet-search-control');
                L.DomEvent.disableClickPropagation(container);

                this._map = map; // マップ参照を保存
                this._currentMarker = null; // マーカー管理用

                this._input = L.DomUtil.create('input', 'leaflet-search-input', container);
                this._input.type = 'text';
                this._input.placeholder = this.options.placeholder;
                this._input.autocomplete = 'off';

                this._ul = L.DomUtil.create('ul', 'leaflet-search-suggestions', container);

                this._debounceTimer = null;

                L.DomEvent.on(this._input, 'input', (e) => {
                    const query = e.target.value.trim();
                    clearTimeout(this._debounceTimer);

                    if (query.length < 2) {
                        this._ul.style.display = 'none';
                        return;
                    }
                    this._debounceTimer = setTimeout(() => this._performSearch(query), 300);
                });

                L.DomEvent.on(this._input, 'focus', () => {
                    if (this._input.value === '') {
                        const history = this._getHistory();
                        if (history.length > 0) {
                            this._renderSuggestions(history.map(h => ({ ...h, source: 'history' })));
                        }
                    }
                });

                this._outsideClickHandler = (e) => {
                    if (!container.contains(e.target)) {
                        this._ul.style.display = 'none';
                    }
                };
                document.addEventListener('click', this._outsideClickHandler);

                return container;
            },

            onRemove: function (map) {
                document.removeEventListener('click', this._outsideClickHandler);
                if (this._currentMarker) {
                    map.removeLayer(this._currentMarker);
                }
            },

            _performSearch: async function (query) {
                const history = this._getHistory();
                const historyResults = history
                    .filter(item => item.name.toLowerCase().includes(query.toLowerCase()))
                    .map(item => ({ ...item, source: 'history' }));

                try {
                    const res = await fetch(`${this.options.nominatimUrl}?format=json&q=${encodeURIComponent(query)}`);
                    const data = await res.json();
                    const webResults = data.map(item => ({
                        name: item.display_name,
                        lat: parseFloat(item.lat),
                        lng: parseFloat(item.lon),
                        source: 'web'
                    }));
                    this._renderSuggestions([...historyResults, ...webResults]);
                } catch (err) {
                    console.error(err);
                    this._renderSuggestions(historyResults);
                }
            },

            _renderSuggestions: function (results) {
                this._ul.innerHTML = '';
                if (results.length === 0) {
                    this._ul.style.display = 'none';
                    return;
                }

                results.slice(0, 10).forEach(item => {
                    const li = L.DomUtil.create('li', '', this._ul);
                    const badgeClass = item.source === 'history' ? 'ls-badge-history' : 'ls-badge-web';
                    const badgeText = item.source === 'history' ? '履歴' : 'Web';
                    li.innerHTML = `<span class="ls-badge ${badgeClass}">${badgeText}</span><span>${item.name}</span>`;

                    L.DomEvent.on(li, 'click', () => this._selectItem(item));
                });
                this._ul.style.display = 'block';
            },

            _selectItem: function (item) {
                if (this.options.autoCollapse) {
                    this._ul.style.display = 'none';
                }

                // 履歴保存
                this._saveToHistory({ name: item.name, lat: item.lat, lng: item.lng });

                // ★ 外部定義のアクションを実行
                // 引数: 選択アイテム, 地図インスタンス, コントロール自身
                if (this.options.onLocationSelected) {
                    this.options.onLocationSelected(item, this._map, this);
                }
            },

            _getHistory: function () {
                const json = localStorage.getItem(this.options.historyKey);
                return json ? JSON.parse(json) : [];
            },

            _saveToHistory: function (item) {
                let history = this._getHistory();
                history = history.filter(h => h.name !== item.name);
                history.unshift(item);
                if (history.length > this.options.maxHistory) history.pop();
                localStorage.setItem(this.options.historyKey, JSON.stringify(history));
            }
        });

        L.control.searchWithHistory = function (opts) {
            return new L.Control.SearchWithHistory(opts);
        }


        // ----------------------------------------------------------------------
        // 使い方：外部からアクションをバインドする例
        // ----------------------------------------------------------------------

        const map = L.map('map').setView([35.6895, 139.6917], 13);
        L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
            attribution: '© OpenStreetMap contributors'
        }).addTo(map);

        // ★ コンポーネント生成時に独自のアクションを指定
        L.control.searchWithHistory({
            position: 'topleft',
            placeholder: '地名・駅名を検索...',

            // 例: デフォルトのマーカーではなく、赤いサークルを描画し、ログを出すだけにする
            onLocationSelected: function (item, map, control) {
                console.log("外部定義アクション実行:", item.name);

                // ズーム移動 (アニメーション付き)
                map.flyTo([item.lat, item.lng], 15);

                // もしコントロール内に前回のレイヤーがあれば削除 (controlに保存しておくと便利)
                if (control._customLayer) {
                    map.removeLayer(control._customLayer);
                }

                // 赤いサークルを追加
                control._customLayer = L.circle([item.lat, item.lng], {
                    color: 'red',
                    fillColor: '#f03',
                    fillOpacity: 0.5,
                    radius: 300
                }).addTo(map).bindPopup(`<b>${item.name}</b><br>ここはカスタムアクションです`).openPopup();
            }

        }).addTo(map);

    </script>
</body>

</html>
