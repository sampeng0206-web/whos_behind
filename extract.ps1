$jsonLines = Get-Content -Path "C:\Users\USER\.gemini\antigravity\brain\9040ee15-82ab-4f59-a302-67b137fc1a89\.system_generated\logs\transcript.jsonl"
foreach ($line in $jsonLines) {
    if ($line -like "*replace_file_content*") {
        $obj = ConvertFrom-Json $line
        foreach ($call in $obj.tool_calls) {
            if ($call.name -eq "replace_file_content") {
                $content = $call.args.ReplacementContent
                $content | Out-File -Encoding utf8 "c:\Users\USER\Desktop\whos_behind\extracted_replacement.dart"
                Write-Output "Extracted successfully"
                break
            }
        }
    }
}
