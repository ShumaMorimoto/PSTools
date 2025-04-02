using module OfficeTools


$response = @{
    order = @("0001", "0002", "0003", "0004")
    posts = [ordered]@{
        "0001" = @{user_id = "u01"; message = "はろ" }
        "0002" = @{user_id = "u02"; message = "グッド" }
        "0003" = @{user_id = "u01"; message = "感じ" }
        "0004" = @{user_id = "u04"; message = "漢字" }
    }
}

$user = @{
    "U01" = @{name = "太郎" }
    "U02" = @{name = "次郎" }
    "U04" = @{name = "花子" }
}

$selectheader = @(
    @{label = "PostID"; expression = { $_.Key } },
    @{label = "UserID"; expression = { $_.Value.user_id } }
    @{label = "投稿者"; expression = { $user.($_.Value.user_id).name } }
    @{label = "投稿"; expression = { $_.Value.message } }
)

$response.posts.GetEnumerator() | Select-Object ($selectheader) | Out-GridView
