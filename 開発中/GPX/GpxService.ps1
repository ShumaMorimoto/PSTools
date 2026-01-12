class GPXService : XmlJsonBase {
    hidden static [string] $ns = "http://www.topografix.com/GPX/1/1"
    hidden static [string] $xsd = "D:\tool\Repository\PSTools\RouteOptimizer\config\gpx.xsd"

    # --- スタティックコンストラクタ (型情報の定義) ---
    static GPXService() {
        # 1. 標準XSDをロード
        [XmlJsonBase]::StaticLoadSchema([GPXService]::ns, [GPXService]::xsd)
        
        # 2. 型キャストを確実にするための明示的なマッピング追加
        [XmlJsonBase]::StaticAddMapping([GPXService]::ns, "lat", "double", $true)
        [XmlJsonBase]::StaticAddMapping([GPXService]::ns, "lon", "double", $true)
        [XmlJsonBase]::StaticAddMapping([GPXService]::ns, "muitiRoute", "string", $true)
    }

    # --- コンストラクタ ---

    # パターン1: デフォルト（新規作成用・雛形あり）
    GPXService() : base([GPXService]::ns, "gpx", [GPXService]::xsd) {
        $this.InitializeModel()
    }

    # パターン2: 既存のハッシュテーブルから生成 (LoadModel を利用)
    GPXService([hashtable]$model) : base([GPXService]::ns, "gpx", [GPXService]::xsd) {
        $this.LoadModel($model)
    }

    # --- ファクトリ ---
    static [GPXService] FromFile([string]$path) {
        $inst = [GPXService]::new()
        $inst.Load($path) # Base の Load を利用
        return $inst
    }

    # --- 内部状態の管理 ---

    # 初期雛形を Model にロードする
    [void] InitializeModel() {
        $this.LoadModel(@{
                version  = "1.1"
                creator  = "GPX Service"
                metadata = @{ time = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ") }
                trk      = @{ trkseg = @{ trkpt = [System.Collections.ArrayList]@() } }
            })
    }

    # --- データの取り出し (ToModel) ---
    [hashtable] ToModel() {
        # PowerShellでの親クラスメソッド呼び出しはキャストを使用します
        return ([XmlJsonBase]$this).ToModel()
    }

    # --- ドメインヘルパー ---

    [object[]] GetTrkpts() {
        return $this.Model.trk.trkseg.trkpt
    }

    [void] AddTrkpt([hashtable]$pt) {
        [void]$this.Model.trk.trkseg.trkpt.Add($pt)
    }
}
