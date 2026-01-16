/**
 * SearchControl.js
 * Leaflet UIコンポーネント
 * (MunicipalityLogic.js の searchGSI 関数を使用します)
 */
import { searchGSI } from './MunicipalityLogic.js';

export function initSearchControl() {
    
    // 二重定義防止
    if (L.Control.SearchWithHistory) return;

    L.Control.SearchWithHistory = L.Control.extend({
        options: {
            position: "topleft",
            placeholder: "場所を検索...",
            maxHistory: 50,
            historyKey: "leaflet_search_history_v4",
            autoCollapse: true,
            onLocationSelected: null, // 選択時のコールバック
        },

        initialize: function (options) {
            L.setOptions(this, options);
        },

        onAdd: function (map) {
            this._map = map;
            const container = L.DomUtil.create("div", "leaflet-search-control leaflet-bar");
            
            // マップへのイベント伝播を防止
            L.DomEvent.disableClickPropagation(container);
            L.DomEvent.disableScrollPropagation(container);
            
            // コンテナの基本スタイル
            container.style.background = "white";
            container.style.position = "relative";
            container.style.padding = "5px";
            container.style.boxShadow = "0 1px 5px rgba(0,0,0,0.4)";
            container.style.borderRadius = "4px";

            // 入力フィールド作成
            this._input = L.DomUtil.create("input", "leaflet-search-input", container);
            this._input.type = "text";
            this._input.placeholder = this.options.placeholder;
            this._input.style.width = "220px";
            this._input.style.padding = "5px";
            this._input.style.border = "1px solid #ccc";
            this._input.style.borderRadius = "3px";
            this._input.autocomplete = "off";

            // 候補リスト（ul）作成
            this._ul = L.DomUtil.create("ul", "leaflet-search-suggestions", container);
            this._ul.style.display = "none";
            this._ul.style.listStyle = "none";
            this._ul.style.margin = "0";
            this._ul.style.padding = "0";
            this._ul.style.position = "absolute";
            this._ul.style.top = "100%";
            this._ul.style.left = "0";
            this._ul.style.right = "0";
            this._ul.style.background = "white";
            this._ul.style.border = "1px solid #ccc";
            this._ul.style.borderTop = "none";
            this._ul.style.zIndex = "9999";
            this._ul.style.maxHeight = "300px";
            this._ul.style.overflowY = "auto";
            this._ul.style.boxShadow = "0 3px 5px rgba(0,0,0,0.2)";

            this._debounceTimer = null;

            // イベント登録
            L.DomEvent.on(this._input, "input", this._onInput, this);
            L.DomEvent.on(this._input, "focus", this._onFocus, this);
            
            // 外側クリックで閉じる
            this._outsideClickHandler = (e) => {
                if (!container.contains(e.target)) {
                    this._ul.style.display = "none";
                }
            };
            document.addEventListener("click", this._outsideClickHandler);

            return container;
        },

        onRemove: function(map) {
            // クリーンアップ
            document.removeEventListener("click", this._outsideClickHandler);
        },

        _onInput: function (e) {
            const val = e.target.value.trim();
            clearTimeout(this._debounceTimer);
            
            if (val.length < 2) {
                this._ul.style.display = "none";
                return;
            }
            
            // 入力停止後300ms待ってから検索
            this._debounceTimer = setTimeout(() => this._performSearch(val), 300);
        },

        _onFocus: function () {
            // 空のときは履歴を表示
            if (this._input.value === "") {
                const hist = this._getHistory();
                if (hist.length > 0) {
                    this._renderSuggestions(hist.map(h => ({ ...h, source: "history" })));
                }
            }
        },

        _performSearch: async function (query) {
            const qLower = query.toLowerCase();
            
            // 履歴からのフィルタリング
            const hist = this._getHistory()
                .filter(h => (h.name || "").toLowerCase().includes(qLower))
                .map(h => ({ ...h, source: "history" }));

            try {
                // 外部ロジックによるWeb検索（並列処理済み）
                const webResults = await searchGSI(query);
                
                // 履歴とWeb検索結果を結合（履歴優先）
                this._renderSuggestions([...hist, ...webResults]);
            } catch (err) {
                console.error("Search failed:", err);
                // エラー時は履歴のみ表示
                this._renderSuggestions(hist);
            }
        },

        _renderSuggestions: function (list) {
            this._ul.innerHTML = "";
            if (!list.length) {
                this._ul.style.display = "none";
                return;
            }

            // 最大10件表示
            list.slice(0, 10).forEach(item => {
                const li = L.DomUtil.create("li", "", this._ul);
                li.style.padding = "8px 10px";
                li.style.cursor = "pointer";
                li.style.borderBottom = "1px solid #eee";
                li.style.fontSize = "13px";
                
                // バッジの色分け
                const isHistory = item.source === "history";
                const badgeText = isHistory ? "履歴" : "Web";
                const badgeColor = isHistory ? "#6c757d" : "#007bff";
                
                li.innerHTML = `
                    <div style="display:flex; align-items:flex-start;">
                        <span style="background:${badgeColor}; color:white; font-size:10px; padding:2px 5px; border-radius:3px; margin-right:8px; margin-top:2px; min-width:30px; text-align:center;">${badgeText}</span>
                        <div>
                            <div style="font-weight:bold; color:#333;">${item.name}</div>
                            <div style="font-size:11px; color:#666; margin-top:2px;">${item.desc || ""}</div>
                        </div>
                    </div>
                `;

                // クリック時の動作
                li.addEventListener("click", (e) => {
                    e.stopPropagation(); // 親への伝播防止
                    this._selectItem(item);
                });
                
                // ホバー効果
                li.onmouseover = () => li.style.background = "#f8f9fa";
                li.onmouseout = () => li.style.background = "white";
                
                this._ul.appendChild(li);
            });
            this._ul.style.display = "block";
        },

        _selectItem: function (item) {
            if (this.options.autoCollapse) {
                this._ul.style.display = "none";
                this._input.value = item.name; // 入力欄を更新
            }
            
            // 履歴に保存
            const savedItem = this._saveToHistory(item);
            
            // コールバック発火
            if (this.options.onLocationSelected) {
                this.options.onLocationSelected(savedItem, this._map);
            }
        },

        _getHistory: function () {
            const json = localStorage.getItem(this.options.historyKey);
            return json ? JSON.parse(json) : [];
        },

        _saveToHistory: function (item) {
            let hist = this._getHistory();
            
            // 重複排除（同じ座標付近のものは削除して先頭へ移動）
            const lat = parseFloat(item.lat);
            const lon = parseFloat(item.lon);
            
            hist = hist.filter(h => {
                const hLat = parseFloat(h.lat);
                const hLon = parseFloat(h.lon);
                // 座標がほぼ同じなら同一地点とみなす
                return !(Math.abs(hLat - lat) < 0.0001 && Math.abs(hLon - lon) < 0.0001);
            });
            
            // sourceプロパティを除去して保存用オブジェクト作成
            const { source, ...saveData } = item;
            
            // 先頭に追加
            hist.unshift(saveData);
            
            // 最大件数制限
            if (hist.length > this.options.maxHistory) {
                hist.pop();
            }
            
            localStorage.setItem(this.options.historyKey, JSON.stringify(hist));
            
            // 保存したデータを履歴ソースとして返す
            return { ...saveData, source: "history" };
        }
    });

    // ファクトリ関数
    L.control.searchWithHistory = function (opts) {
        return new L.Control.SearchWithHistory(opts);
    };
}
