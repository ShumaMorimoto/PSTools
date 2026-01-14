class GPXService : XmlJsonBase {
    hidden static [string] $ns = "http://www.topografix.com/GPX/1/1"
    hidden static [string] $xsd = ""

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

    # ----------------------------
    # Track Point Operations
    # ----------------------------
    [object[]] GetTrkpts() {
        return $this.Model.trk.trkseg.trkpt
    }

    [void] SetTrkpts([object[]] $pts) {
        $this.Model.trk.trkseg.trkpt = $pts
    }

    [void] AppendTrkpt([hashtable] $trkpt) {
        if (-not $trkpt.lat -or -not $trkpt.lon) {
            throw "lat and lon are required"
        }
        $this.Model.trk.trkseg.trkpt += $trkpt
    }
    # ----------------------------
    # Waypoint Operations
    # ----------------------------
    [object[]] GetWpts() {
        return $this.Model.wpt
    }

    [void] SetWpts([object[]] $wpts) {
        $this.Model.wpt = $wpts
    }

    [void] AppendWpt([hashtable] $wpt) {
        if (-not $wpt.lat -or -not $wpt.lon) {
            throw "lat and lon are required"
        }
        $this.Model.wpt += $wpt
    }

    [void] RemoveTrkpt([hashtable] $pt) {
        $list = $this.Model.trk.trkseg.trkpt
        $this.Model.trk.trkseg.trkpt = $list | Where-Object { $_ -ne $pt }
    }

    # --- 静的メソッド ---

    static [hashtable[]] NormalizeData($input) {
        # 位置指定（lat/lonがあるハッシュテーブル）なら住所解決して1件のリストにする
        if ($input -is [hashtable] -and $input.lat -and $input.lon) {
            $pt = [GeoService]::ResolveAddress($input)
            return @($pt)
        }

        # キーワード抽出 (PowerShell 7.0+ の三項演算子、または if で対応)
        $keyword = if ($input -is [hashtable]) { $input.keyword } else { $input }

        # キーワード検索 → trkpt 候補を返す
        return [GeoService]::SearchPlace($keyword)
    }

    static [GPXService] Search($input) {
        $gpx = [GPXService]::new()

        # 1. keyword を metadata に保存
        if ($input -is [string]) {
            $gpx.Model.metadata.keywords = $input
        }
        elseif ($input -is [hashtable] -and $input.keyword) {
            $gpx.Model.metadata.keywords = $input.keyword
        }

        # 2. NormalizeData
        $pts = [GPXService]::NormalizeData($input)
        switch ($pts.Count) {
            0 { }
            1 {
                $pt = $pts[0]
                $gpx.Model.metadata.name = $pt.name
                $gpx.Model.metadata.desc = $pt.desc
                $gpx.Model.metadata.extensions = $pt.extensions
                $gpx.SetTrkpts(@($pt))
            }
            default {
                # 候補が複数ある場合は Waypoints としてセット
                $gpx.SetWpts($pts)
            }
        }
        return $gpx
    }

    static [GPXService] FromCityTowns($input) {
        $gpx = [GPXService]::new()
        if ($input -is [string]) {0
            $gpx.Model.metadata.keywords = $input
        }
        elseif ($input -is [hashtable] -and $input.keyword) {
            $gpx.Model.metadata.keywords = $input.keyword
        }

        $pts = [GPXService]::NormalizeData($input)
        switch ($pts.Count) {
            0 { }
            1 {
                $pt = $pts[0]
                $gpx.Model.metadata.name = $pt.name
                $gpx.Model.metadata.desc = $pt.desc
                $gpx.Model.metadata.extensions = $pt.extensions

                # 自治体内の町字を取得してトラックポイントに設定
                $towns = [GeoService]::QueryTowns($pt)
                $gpx.SetTrkpts($towns)
            }
            default {
                $gpx.SetWpts($pts)
            }
        }
        return $gpx
    }

    static [GPXService] FromAreaTowns($input) {
        $gpx = [GPXService]::new()

        if ($input -is [string]) {
            $gpx.Model.metadata.keywords = $input
        }
        elseif ($input -is [hashtable] -and $input.keyword) {
            $gpx.Model.metadata.keywords = $input.keyword
        }

        $pts = [GPXService]::NormalizeData($input)
        switch ($pts.Count) {
            0 { }
            1 {
                $pt = $pts[0]
                $gpx.Model.metadata.name = $pt.name
                $gpx.Model.metadata.desc = $pt.desc
                $gpx.Model.metadata.extensions = $pt.extensions

                # 半径指定などのエリア検索
                $areas = [GeoService]::QueryArea($pt)
                $gpx.SetTrkpts($areas)
            }
            default {
                $gpx.SetWpts($pts)
            }
        }

        return $gpx
    }
}

# --- クラス定義後の静的初期化 ---
[GPXService]::xsd = Join-Path $script:ModuleRoot "config\gpx.xsd"
