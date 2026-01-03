using Google.OrTools.ConstraintSolver;


namespace TspSolverLib
{
    public static class TspSolver
    {
        // -----------------------------------------
        // 1. Places → Solve（高レベル API）
        // -----------------------------------------
        public static int[] Solve((double lat, double lon)[] places)
        {
            long[,] matrix = DistanceBuilder.BuildGlobalMatrix(places);
            return OrToolsTsp.SolveFull(matrix);
        }
    }

    public static class OrToolsTsp
    {

        // ============================================================
        // 1. Matrix 全体の TSP
        // ============================================================
        public static int[] SolveFull(long[,] matrix, int? startNode = null)
        {
            int n = matrix.GetLength(0);
            int[] nodes = Enumerable.Range(0, n).ToArray();
            return SolveSubset(matrix, nodes, startNode);
        }
        // ============================================================
        // 2. サブセット TSP
        // ============================================================
        public static int[] SolveSubset(long[,] matrix, int[] subset, int? startNodeGlobal = null)
        {
            bool excludeStart = startNodeGlobal.HasValue;
            int startNode = startNodeGlobal ?? -1;

            List<int> visitList = subset.ToList();
            if (startNodeGlobal.HasValue)
            {
                if (!visitList.Contains(startNode))
                {
                    visitList.Insert(0, startNode);
                }
            }

            int m = visitList.Count;
            long[,] subMatrix = new long[m, m];
            for (int i = 0; i < m; i++)
                for (int j = 0; j < m; j++)
                    subMatrix[i, j] = matrix[visitList[i], visitList[j]];

            int subStart = (startNodeGlobal.HasValue) ? visitList.IndexOf(startNode) : -1;

            int[] subRoute = SolveMatrixInternal(subMatrix, subStart);

            List<int> result = new List<int>();
            foreach (int subIdx in subRoute)
            {
                int node = visitList[subIdx];
                if (excludeStart && node == startNode) continue;
                result.Add(node);
            }
            return result.ToArray();
        }
        // ============================================================
        // 3. 区間 TSP（部分最適化）
        // ============================================================
        public static int[] SolveSegment(long[,] matrix, int[] route, int startPos, int endPos)
        {
            if (startPos < 0 || endPos >= route.Length || startPos >= endPos)
                throw new ArgumentException("StartPos / EndPos が不正です。");
            int len = endPos - startPos + 1;
            // 区間抽出
            int[] segment = new int[len];
            Array.Copy(route, startPos, segment, 0, len);
            // 区間の先頭を始点として最適化（残りをサブセットとして）
            int[] newSegment = SolveSubset(matrix, segment.Skip(1).ToArray(), segment[0]);
            // 埋め戻し
            List<int> result = new List<int>();
            if (startPos > 0) result.AddRange(route[..startPos]);
            result.Add(segment[0]);
            result.AddRange(newSegment);
            if (endPos < route.Length - 1) result.AddRange(route[(endPos + 1)..]);
            return result.ToArray();
        }
        // ============================================================
        // 4. OR-Tools TSP 本体（long メートル版）
        // ============================================================
        private static int[] SolveMatrixInternal(long[,] matrix, int startNode = -1)
        {
            int originalSize = matrix.GetLength(0);
            long penalty = CalculatePenalty(matrix, originalSize);

            long[,] distMatrix;
            int numNodes;
            int routeStart;
            int routeEnd;

            if (startNode == -1)
            {
                // No start specified: add dummy start and dummy end
                int dummyStart = originalSize;
                int dummyEnd = originalSize + 1;
                numNodes = originalSize + 2;
                distMatrix = new long[numNodes, numNodes];
                InitializeMatrix(distMatrix, penalty);
                CopyOriginalMatrix(distMatrix, matrix, originalSize);

                // From dummy start to all original nodes: 0 cost
                for (int j = 0; j < originalSize; j++)
                {
                    distMatrix[dummyStart, j] = 0;
                }

                // From all original nodes to dummy end: 0 cost
                for (int i = 0; i < originalSize; i++)
                {
                    distMatrix[i, dummyEnd] = 0;
                }

                routeStart = dummyStart;
                routeEnd = dummyEnd;
            }
            else
            {
                // Start specified: add only dummy end
                int dummyEnd = originalSize;
                numNodes = originalSize + 1;
                distMatrix = new long[numNodes, numNodes];
                InitializeMatrix(distMatrix, penalty);
                CopyOriginalMatrix(distMatrix, matrix, originalSize);

                // From all original nodes to dummy end: 0 cost
                for (int i = 0; i < originalSize; i++)
                {
                    distMatrix[i, dummyEnd] = 0;
                }

                routeStart = startNode;
                routeEnd = dummyEnd;
            }

            var manager = new RoutingIndexManager(numNodes, 1, new int[] { routeStart }, new int[] { routeEnd });
            var routing = new RoutingModel(manager);
            int transitCallbackIndex = routing.RegisterTransitCallback(
                (long fromIndex, long toIndex) =>
                {
                    int fromNode = manager.IndexToNode(fromIndex);
                    int toNode = manager.IndexToNode(toIndex);
                    return distMatrix[fromNode, toNode];
                });
            routing.SetArcCostEvaluatorOfAllVehicles(transitCallbackIndex);
            var searchParameters = operations_research_constraint_solver
                .DefaultRoutingSearchParameters();
            searchParameters.FirstSolutionStrategy =
                FirstSolutionStrategy.Types.Value.PathCheapestArc;
            var solution = routing.SolveWithParameters(searchParameters);
            if (solution == null)
                return Array.Empty<int>();

            int[] route = new int[originalSize];
            long index = routing.Start(0);
            int k = 0;
            while (!routing.IsEnd(index))
            {
                int node = manager.IndexToNode(index);
                if (node < originalSize)
                {
                    route[k++] = node;
                }
                index = solution.Value(routing.NextVar(index));
            }
            return route;
        }

        private static long CalculatePenalty(long[,] matrix, int size)
        {
            long maxValue = long.MinValue;
            foreach (long value in matrix)
            {
                if (value > maxValue) maxValue = value;
            }
            // Penalty larger than any possible path cost
            return 1L + maxValue * size;
        }

        private static void InitializeMatrix(long[,] matrix, long penalty)
        {
            int size = matrix.GetLength(0);
            for (int i = 0; i < size; i++)
            {
                for (int j = 0; j < size; j++)
                {
                    matrix[i, j] = penalty;
                }
            }
        }

        private static void CopyOriginalMatrix(long[,] target, long[,] source, int originalSize)
        {
            for (int i = 0; i < originalSize; i++)
            {
                for (int j = 0; j < originalSize; j++)
                {
                    target[i, j] = source[i, j];
                }
            }
        }
    }
}