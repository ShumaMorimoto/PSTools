<!DOCTYPE html>
<html lang="ja">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Leaflet Search (Keyword Only History)</title>
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
    <style>
        /* デザインは変更なし */
        body {
            margin: 0;
            padding: 0;
            font-family: sans-serif;
        }

        #map {
            height: 100vh;
            width: 100%;
        }

        .leaflet-search-control {
            background: white;
            border-radius: 4px;
            box-shadow: 0 1px 5px rgba(0, 0, 0, 0.4);
            padding: 10px;
            width: 350px;
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
            max-height: 300px;
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
            min-width: 35px;
            text-align: center;
            flex-shrink: 0;
        }

        .ls-badge-history {
            background-color: #28a745;
        }

        .ls-badge-web {
            background-color: #007bff;
        }

        .ls-meta {
            font-size: 10px;
            color: #888;
            margin-left: auto;
            padding-left: 10px;
            white-space: nowrap;
        }

        .item-content {
            display: flex;
            flex-direction: column;
            overflow: hidden;
        }

        .item-name {
            font-weight: bold;
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
        }

        .item-desc {
            font-size: 11px;
            color: #666;
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
        }
    </style>
</head>

<body>
    <div id="map"></div>
    <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>

    <script>
        L.Control.SearchWithHistory = L.Control.extend({
            options: {
                position: 'topleft',
                placeholder: '場所を検索...',
                maxHistory: 20,
                historyKey: 'leaflet_search_history_keyword_only',
                nominatimUrl: 'https://nominatim.openstreetmap.org/search',
                autoCollapse: true,
                onLocationSelected: null
            },

            onAdd: function (map) {
                const container = L.DomUtil.create('div', 'leaflet-search-control');
                L.DomEvent.disableClickPropagation(container);
                this._map = map;
                this._input = L.DomUtil.create('input', 'leaflet-search-input', container);
                this._input.type = 'text';
                this._input.placeholder = this.options.placeholder;
                this._input.autocomplete = 'off';
                this._ul = L.DomUtil.create('ul', 'leaflet-search-suggestions', container);
                this._debounceTimer = null;

                L.DomEvent.on(this._input, 'input', (e) => {
                    const query = e.target.value.trim();
                    clearTimeout(this._debounceTimer);
                    if (query.length < 2) { this._ul.style.display = 'none'; return; }
                    this._debounceTimer = setTimeout(() => this._performSearch(query), 300);
                });

                L.DomEvent.on(this._input, 'focus', () => {
                    if (this._input.value === '') {
                        const history = this._getHistory();
                        if (history.length > 0) this._renderSuggestions(history.map(h => ({ ...h, source: 'history' })));
                    }
                });

                this._outsideClickHandler = (e) => {
                    if (!container.contains(e.target)) this._ul.style.display = 'none';
                };
                document.addEventListener('click', this._outsideClickHandler);
                return container;
            },

            onRemove: function () { document.removeEventListener('click', this._outsideClickHandler); },

            _performSearch: async function (query) {
                const qLower = query.toLowerCase();
                const history = this._getHistory();

                // ★ 変更点: 履歴検索ロジックを修正
                // nameやdescは見ず、keywordのみで判定する
                const historyResults = history.filter(item => {
                    // keywordが存在すればそれを使う
                    if (item.extensions && item.extensions.keyword) {
                        return item.extensions.keyword.toLowerCase().includes(qLower);
                    }
                    // keywordが無い古いデータの場合は、フォールバックとしてnameを見る（安全策）
                    return item.name.toLowerCase().includes(qLower);
                }).map(item => ({ ...item, source: 'history' }));

                try {
                    const res = await fetch(`${this.options.nominatimUrl}?format=json&q=${encodeURIComponent(query)}`);
                    const data = await res.json();
                    const webResults = data.map(item => ({
                        lat: parseFloat(item.lat),
                        lon: parseFloat(item.lon),
                        name: item.name || item.display_name.split(',')[0],
                        desc: item.display_name,
                        extensions: { keyword: query },
                        source: 'web'
                    }));
                    this._renderSuggestions([...historyResults, ...webResults]);
                } catch (err) {
                    this._renderSuggestions(historyResults);
                }
            },

            _renderSuggestions: function (results) {
                this._ul.innerHTML = '';
                if (results.length === 0) { this._ul.style.display = 'none'; return; }
                results.slice(0, 10).forEach(item => {
                    const li = L.DomUtil.create('li', '', this._ul);
                    const isHistory = item.source === 'history';
                    let metaText = '';

                    if (isHistory && item.extensions) {
                        const count = item.extensions.count || 1;
                        metaText = `${count}回`;

                        // デバッグ用に、どのキーワードでヒットしたかを表示（本番では消しても良い）
                        if (item.extensions.keyword) {
                            metaText += ` [key:${item.extensions.keyword}]`;
                        }
                    }
                    li.innerHTML = `
                        <span class="ls-badge ${isHistory ? 'ls-badge-history' : 'ls-badge-web'}">${isHistory ? '履歴' : 'Web'}</span>
                        <div class="item-content"><span class="item-name">${item.name}</span><span class="item-desc">${item.desc || ''}</span></div>
                        <span class="ls-meta">${metaText}</span>
                    `;
                    L.DomEvent.on(li, 'click', () => this._selectItem(item));
                });
                this._ul.style.display = 'block';
            },

            _selectItem: function (item) {
                if (this.options.autoCollapse) this._ul.style.display = 'none';

                const savedItem = this._saveToHistory(item);

                // 更新用関数: {lat, lon, name, desc} などのオブジェクトを受け取る
                const updateHistory = (params) => {
                    const history = this._getHistory();
                    if (history.length > 0) {
                        const target = history[0];

                        if (params.lat !== undefined) target.lat = params.lat;
                        if (params.lon !== undefined) target.lon = params.lon;
                        if (params.name !== undefined) target.name = params.name;
                        if (params.desc !== undefined) target.desc = params.desc;
                        // keyword は更新しない（元の検索語句を維持するため）

                        target.extensions.timestamp = new Date().toISOString();

                        localStorage.setItem(this.options.historyKey, JSON.stringify(history));
                        console.log("履歴更新完了:", target);
                    }
                };

                if (this.options.onLocationSelected) {
                    this.options.onLocationSelected(savedItem, this._map, this, updateHistory);
                }
            },

            _getHistory: function () {
                const json = localStorage.getItem(this.options.historyKey);
                return json ? JSON.parse(json) : [];
            },

            _saveToHistory: function (newItem) {
                let history = this._getHistory();
                const now = new Date().toISOString();

                // 既存チェック: 「キーワード」と「座標」が一致するものを同一とみなすロジックに変更
                // (名前が変わっても、同じ検索結果としてカウントアップさせるため)
                const existingIndex = history.findIndex(h =>
                    h.extensions.keyword === newItem.extensions.keyword &&
                    Math.abs(h.lat - newItem.lat) < 0.0001 &&
                    Math.abs(h.lon - newItem.lon) < 0.0001
                );

                let targetItem;
                if (existingIndex > -1) {
                    targetItem = history[existingIndex];
                    targetItem.extensions.count = (targetItem.extensions.count || 1) + 1;
                    targetItem.extensions.timestamp = now;
                    // name, desc, lat, lon は上書きしない（前回編集した状態を維持）
                    history.splice(existingIndex, 1);
                } else {
                    targetItem = {
                        lat: newItem.lat, lon: newItem.lon, name: newItem.name, desc: newItem.desc || '',
                        extensions: {
                            keyword: (newItem.extensions && newItem.extensions.keyword) || '',
                            timestamp: now,
                            count: 1
                        }
                    };
                }
                history.unshift(targetItem);
                if (history.length > this.options.maxHistory) history.pop();
                localStorage.setItem(this.options.historyKey, JSON.stringify(history));
                return targetItem;
            }
        });

        L.control.searchWithHistory = function (opts) { return new L.Control.SearchWithHistory(opts); }

        // ----------------------------------------------------------------------
        // 動作確認用
        // ----------------------------------------------------------------------
        const map = L.map('map').setView([35.6895, 139.6917], 13);
        L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', { attribution: '© OpenStreetMap contributors' }).addTo(map);

        L.control.searchWithHistory({
            onLocationSelected: function (item, map, control, updateHistory) {
                console.log("選択アイテム:", item);

                map.setView([item.lat, item.lon], 16);
                if (control._marker) map.removeLayer(control._marker);

                // ポップアップ内に「名前変更」「位置移動」のUIを入れる例
                const content = document.createElement('div');
                content.innerHTML = `
                    <div style="margin-bottom:8px;">
                        <input type="text" id="renameInput" value="${item.name}" style="width:100%">
                    </div>
                    <div style="font-size:11px; color:#666;">
                        ${item.desc}<br>
                        (Keyword: ${item.extensions.keyword})
                    </div>
                    <button id="saveBtn" style="margin-top:5px;">名前を保存</button>
                    <p style="font-size:10px; color:red;">※マーカーをドラッグで位置修正</p>
                `;

                // ボタンイベント
                setTimeout(() => {
                    const btn = content.querySelector('#saveBtn');
                    const input = content.querySelector('#renameInput');
                    if (btn && input) {
                        btn.onclick = () => {
                            const newName = input.value;
                            // ★ 名前だけ更新。検索キーワード(keyword)は変わらないので、
                            //    次回も元のキーワード検索でこの「新しい名前」が表示される。
                            updateHistory({ name: newName });
                            alert(`名前を「${newName}」に変更しました。\n次回からキーワード「${item.extensions.keyword}」で検索すると、この名前で表示されます。`);
                            control._marker.closePopup();
                        };
                    }
                }, 0);

                control._marker = L.marker([item.lat, item.lon], { draggable: true })
                    .addTo(map)
                    .bindPopup(content)
                    .openPopup();

                control._marker.on('dragend', function (e) {
                    const pos = e.target.getLatLng();
                    // 位置のみ更新
                    updateHistory({ lat: pos.lat, lon: pos.lng });
                    control._marker.bindPopup(content).openPopup(); // ポップアップ再バインド
                });
            }
        }).addTo(map);
    </script>
</body>

</html>
