// ui-manager.js

export default class UIManager {
    constructor(selector) {
        this.selector = selector;
    }

    initUIHandlers() {
        document.getElementById(this.selector.controls.toggleLockBtnId).addEventListener('click', () => this.selector.imageHandler.toggleLockMode());
        document.getElementById(this.selector.controls.clearMarkersBtnId).addEventListener('click', () => this.selector.markerHandler.clearMarkers());
        document.getElementById(this.selector.controls.finishBtnId).addEventListener('click', () => this.finish());
        document.getElementById(this.selector.controls.pointListId).addEventListener('change', () => this.handlePointListChange());
    }

    updateListUI() {
        const list = document.getElementById(this.selector.controls.pointListId);
        list.innerHTML = "";

        if (this.selector.markerHandler.pointList.length === 0) {
            const opt = document.createElement("option");
            opt.text = "(地点を選択してください)";
            list.appendChild(opt);
            return;
        }

        this.selector.markerHandler.pointList.forEach((p, i) => {
            const label = p.name || p.desc || "取得中...";
            const opt = document.createElement("option");
            opt.value = i;
            opt.text = `${i+1}: ${label}`;
            list.appendChild(opt);
        });

        if (this.selector.markerHandler.selectedIndex !== null) list.value = this.selector.markerHandler.selectedIndex;
    }

    handlePointListChange() {
        const list = document.getElementById(this.selector.controls.pointListId);
        const val = list.value;
        if (val === "" || isNaN(val)) return;
        const idx = parseInt(val);

        this.selector.markerHandler.selectedIndex = idx;
        const p = this.selector.markerHandler.pointList[idx];
        this.selector.map.setView([p.lat, p.lon], this.selector.map.getZoom());
        this.selector.markerHandler.renumberMarkers();
    }

    finish() {
        const btn = document.getElementById(this.selector.controls.finishBtnId);

        if (btn.dataset.state === "done") {
            window.close();
            return;
        }

        btn.textContent = "送信中...";
        btn.disabled = true;

        fetch("/choice", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(this.selector.markerHandler.pointList)
        })
        .then(() => fetch("/done", { method: "POST" }))
        .then(() => {
            btn.textContent = "完了 (閉じる)";
            btn.disabled = false;
            btn.dataset.state = "done";
            btn.style.backgroundColor = "#28a745";
        })
        .catch((e) => {
            console.error("送信エラー:", e);
            alert("サーバーへの送信に失敗しました。\n(ブラウザ単体テストではこのエラーが出ますが、動作ロジックは正常です)");
            btn.textContent = "登録";
            btn.disabled = false;
        });
    }
}