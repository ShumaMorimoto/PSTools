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

            // NumClustersをMaxGroupSizeに基づいて最小限に調整
            int minClusters = (int)Math.Ceiling((double)n / maxGroupSize);
            if (numClusters < minClusters) numClusters = minClusters;

            // 初期中心点をランダム選択
            var random = new Random();
            var indices = Enumerable.Range(0, n).OrderBy(x => random.Next()).Take(numClusters).ToArray();
            var centers = indices.Select(idx => places[idx]).ToArray();

            // イテレーション
            bool changed;
            var clusters = new List<int>[numClusters];
            do
            {
                // クラスタ初期化
                for (int c = 0; c < numClusters; c++) clusters[c] = new List<int>();

                // 各ポイントを最近傍中心に割り当て
                for (int i = 0; i < n; i++)
                {
                    long minDist = long.MaxValue;
                    int closest = -1;
                    for (int c = 0; c < numClusters; c++)
                    {
                        long dist = DistanceBuilder.HaversineMeters(places[i], centers[c]);
                        if (dist < minDist)
                        {
                            minDist = dist;
                            closest = c;
                        }
                    }
                    clusters[closest].Add(i);
                }

                // 中心点を更新
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

                    // 変化チェック（簡易閾値）
                    if (Math.Abs(newCenter.lat - centers[c].lat) > 1e-6 || Math.Abs(newCenter.lon - centers[c].lon) > 1e-6)
                    {
                        changed = true;
                    }
                    centers[c] = newCenter;
                }

            } while (changed && --maxIterations > 0);

            // 各クラスタをMaxGroupSize以内に分割
            var result = new List<List<int>>();
            foreach (var group in clusters.Where(g => g != null && g.Count > 0))
            {
                for (int i = 0; i < group.Count; i += maxGroupSize)
                {
                    var subGroup = group.Skip(i).Take(maxGroupSize).ToList();
                    result.Add(subGroup);
                }
            }

            return result;
        }
    }
}