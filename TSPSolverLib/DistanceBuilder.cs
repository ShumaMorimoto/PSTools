namespace TspSolverLib
{
    public static class DistanceBuilder
    {
        public static long[,] BuildGlobalMatrix((double lat, double lon)[] places)
        {
            int n = places.Length;
            long[,] mat = new long[n, n];

            for (int i = 0; i < n; i++)
            {
                for (int j = 0; j < n; j++)
                {
                    mat[i, j] = (i == j)
                        ? long.MaxValue
                        : HaversineMeters(places[i], places[j]);
                }
            }
            return mat;
        }

        public static long GetRouteDistance(int[] route, long[,] distanceMatrix)
        {
            if (route.Length <= 1) return 0;

            long sum = 0;
            for (int i = 0; i < route.Length - 1; i++)
            {
                sum += distanceMatrix[route[i], route[i + 1]];
            }
            return sum;
        }

        public static long HaversineMeters((double lat, double lon) p1,
                                           (double lat, double lon) p2)
        {
            const double R = 6371000.0;

            double dLat = ToRad(p2.lat - p1.lat);
            double dLon = ToRad(p2.lon - p1.lon);

            double lat1 = ToRad(p1.lat);
            double lat2 = ToRad(p2.lat);

            double a =
                Math.Pow(Math.Sin(dLat / 2), 2) +
                Math.Cos(lat1) * Math.Cos(lat2) *
                Math.Pow(Math.Sin(dLon / 2), 2);

            double c = 2 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a));

            return (long)Math.Round(R * c);
        }

        private static double ToRad(double deg) => deg * Math.PI / 180.0;

        /// <summary>
        /// クラスタ間距離行列を作成する
        /// </summary>
        /// <param name="clusterData">ArrayList（各クラスタの情報）</param>
        /// <param name="globalDist">グローバル距離行列（long メートル）</param>
        /// <returns>クラスタ間距離行列（long メートル）</returns>
        public static long[,] NewClusterDistanceMatrix(int[][] bestRoutes, long[,] globalDist)
        {
            int k = bestRoutes.Length;
            long[,] mat = new long[k, k];

            for (int i = 0; i < k; i++)
            {
                int[] routeI = bestRoutes[i];
                int exitNode = routeI[routeI.Length - 1];

                for (int j = 0; j < k; j++)
                {
                    if (i == j)
                    {
                        mat[i, j] = long.MaxValue;
                    }
                    else
                    {
                        int[] routeJ = bestRoutes[j];
                        int entryNode = routeJ[0];

                        mat[i, j] = globalDist[exitNode, entryNode];
                    }
                }
            }

            return mat;
        }

    }
}