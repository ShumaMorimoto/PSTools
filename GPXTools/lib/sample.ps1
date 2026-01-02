Set-Location D:\tool\TspSolver

Add-Type -LiteralPath "D:\tool\TspSolver\TspSolverLib.dll"

# 距離行列
$matrix = [double[,]]::new(4,4)
$matrix[0,1] = 10; $matrix[0,2] = 15; $matrix[0,3] = 20
$matrix[1,0] = 10; $matrix[1,2] = 35; $matrix[1,3] = 25
$matrix[2,0] = 15; $matrix[2,1] = 35; $matrix[2,3] = 30
$matrix[3,0] = 20; $matrix[3,1] = 25; $matrix[3,2] = 30

$route = [TspSolverLib.TspSolver]::Solve($matrix)
$route
