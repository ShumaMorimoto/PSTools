namespace TspSolverLib
{
    public static class Clustering
    {
        /// <summary>
        /// K-Meansクラスタリング（Haversine距離使用）。中心は緯度経度の平均。
        /// NumClustersはMaxGroupSizeに基づいて最小限に調整。
        /// </summary>
        /// <param name="places">緯度経度の配列</param>
        /// <param name="numClusters">初期クラスタ数（自動調整）</param>
        /// <param name="maxGroupSize">クラスタ上限サイズ</param>
        /// <param name="maxIterations">最大イテレーション</param>
        /// <returns>クラスタごとのインデックスリストのリスト</returns>
        public static List<List<int>> MeshCluster((double lat, double lon)[] places, double meshKm = 5.0, int maxGroupSize = 50)
        {
            int n = places.Length;
            if (n == 0) return new List<List<int>>();

            // 平均緯度を計算（経度デルタ用）
            double avgLat = places.Average(p => p.lat);
            double deltaLat = meshKm / 111.0;  // 緯度1度 ≈ 111 km
            double deltaLon = meshKm / (111.0 * Math.Cos(avgLat * Math.PI / 180.0));

            // メッシュキーでグループ化
            var meshGroups = new Dictionary<string, List<int>>();
            for (int i = 0; i < n; i++)
            {
                var place = places[i];
                int keyLat = (int)Math.Floor(place.lat / deltaLat);
                int keyLon = (int)Math.Floor(place.lon / deltaLon);
                string key = $"{keyLat},{keyLon}";

                if (!meshGroups.ContainsKey(key))
                {
                    meshGroups[key] = new List<int>();
                }
                meshGroups[key].Add(i);
            }

            // 各グループをMaxGroupSize以内に分割
            var result = new List<List<int>>();
            foreach (var group in meshGroups.Values)
            {
                for (int i = 0; i < group.Count; i += maxGroupSize)
                {
                    var subGroup = group.Skip(i).Take(maxGroupSize).ToList();
                    result.Add(subGroup);
                }
            }

            return result;
        }

        /// <summary>
        /// K-Meansクラスタリング（Haversine距離使用）。中心は緯度経度の平均。
        /// NumClustersはMaxGroupSizeに基づいて最小限に調整。
        /// </summary>
        /// <param name="places">緯度経度の配列</param>
        /// <param name="numClusters">初期クラスタ数（自動調整）</param>
        /// <param name="maxGroupSize">クラスタ上限サイズ</param>
        /// <param name="maxIterations">最大イテレーション</param>
        /// <returns>クラスタごとのインデックスリストのリスト</returns>
        public static List<List<int>> KMeansCluster((double lat, double lon)[] places, int numClusters = 10, int maxGroupSize = 50, int maxIterations = 100)
        {
            int n = places.Length;
            if (n == 0) return new List<List<int>>();

            // --- 追加の改善: 拠点数がグループサイズ以下なら即座に1つにまとめて返す ---
            if (n <= maxGroupSize)
            {
                return new List<List<int>> { Enumerable.Range(0, n).ToList() };
            }

            // --- 拠点数が指定クラスタ数より少ない場合の調整 ---
            // 最小限必要なクラスタ数 (n/maxSize) と、最大でも n 個（1拠点1クラスタ）の間に収める
            int minRequiredClusters = (int)Math.Ceiling((double)n / maxGroupSize);
            numClusters = Math.Max(numClusters, minRequiredClusters);
            if (numClusters > n) numClusters = n; // 拠点数以上のクラスタは作れない

            var random = new Random();

            // 初期中心点をランダムに選択（重複なしで n から numClusters 個選ぶ）
            var centers = Enumerable.Range(0, n)
                                    .OrderBy(x => random.Next())
                                    .Take(numClusters)
                                    .Select(idx => places[idx])
                                    .ToArray();

            var clusters = new List<int>[numClusters];
            bool changed;

            do
            {
                for (int c = 0; c < numClusters; c++) clusters[c] = new List<int>();

                // 各ポイントを最近傍中心に割り当て
                for (int i = 0; i < n; i++)
                {
                    double minDist = double.MaxValue; // メートル計算ならdoubleが一般的
                    int closest = 0;
                    for (int c = 0; c < numClusters; c++)
                    {
                        double dist = DistanceBuilder.HaversineMeters(places[i], centers[c]);
                        if (dist < minDist)
                        {
                            minDist = dist;
                            closest = c;
                        }
                    }
                    clusters[closest].Add(i);
                }

                changed = false;
                for (int c = 0; c < numClusters; c++)
                {
                    if (clusters[c].Count == 0) continue;

                    double sumLat = 0, sumLon = 0;
                    foreach (int idx in clusters[c])
                    {
                        sumLat += places[idx].lat;
                        sumLon += places[idx].lon;
                    }
                    var newCenter = (lat: sumLat / clusters[c].Count, lon: sumLon / clusters[c].Count);

                    if (Math.Abs(newCenter.lat - centers[c].lat) > 1e-6 || Math.Abs(newCenter.lon - centers[c].lon) > 1e-6)
                    {
                        changed = true;
                        centers[c] = newCenter;
                    }
                }
            } while (changed && --maxIterations > 0);

            // 各クラスタをMaxGroupSize以内に分割して平準化
            var result = new List<List<int>>();
            foreach (var group in clusters.Where(g => g != null && g.Count > 0))
            {
                for (int i = 0; i < group.Count; i += maxGroupSize)
                {
                    result.Add(group.Skip(i).Take(maxGroupSize).ToList());
                }
            }

            return result;
        }
    }
}