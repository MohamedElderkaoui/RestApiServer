# PowerShell script to dump all people data from RestApiServer to JSON
param(
    [string]$ServerUrl = "http://localhost:8080/people",
    [string]$OutputFile = "people_data.json",
    [switch]$Pretty = $true,
    [switch]$OpenFile = $false
)

Write-Host "🗃️ Dumping data from RestApiServer..." -ForegroundColor Green
Write-Host "=================================" -ForegroundColor Cyan
Write-Host "Server URL: $ServerUrl" -ForegroundColor Yellow
Write-Host "Output File: $OutputFile" -ForegroundColor Yellow
Write-Host "=================================" -ForegroundColor Cyan
Write-Host

try {
    # Check if server is running
    Write-Host "🔍 Checking server availability..." -ForegroundColor Blue
    $response = Invoke-RestMethod -Uri $ServerUrl -Method GET -TimeoutSec 10
    Write-Host "✅ Server is accessible" -ForegroundColor Green
    
    # Get the data
    Write-Host "📊 Fetching all people data..." -ForegroundColor Blue
    $peopleData = $response
    $count = $peopleData.Count
    
    if ($count -eq 0) {
        Write-Host "⚠️ No data found on server" -ForegroundColor Yellow
        $emptyData = @()
        $jsonContent = $emptyData | ConvertTo-Json -Depth 3
    } else {
        Write-Host "✅ Found $count people in the database" -ForegroundColor Green
        
        # Convert to JSON with proper formatting
        if ($Pretty) {
            $jsonContent = $peopleData | ConvertTo-Json -Depth 3 -Compress:$false
        } else {
            $jsonContent = $peopleData | ConvertTo-Json -Depth 3 -Compress
        }
    }
    
    # Write to file
    Write-Host "💾 Writing data to file: $OutputFile" -ForegroundColor Blue
    $jsonContent | Out-File -FilePath $OutputFile -Encoding UTF8
    
    # Get file info
    $fileInfo = Get-Item $OutputFile
    $fileSizeKB = [math]::Round($fileInfo.Length / 1024, 2)
    
    Write-Host
    Write-Host "🎉 Data dump completed successfully!" -ForegroundColor Green
    Write-Host "=================================" -ForegroundColor Cyan
    Write-Host "📊 Statistics:" -ForegroundColor Yellow
    Write-Host "   📋 Total records: $count" -ForegroundColor White
    Write-Host "   📁 File size: $fileSizeKB KB" -ForegroundColor White
    Write-Host "   📄 File path: $(Resolve-Path $OutputFile)" -ForegroundColor White
    Write-Host "   📅 Created: $($fileInfo.LastWriteTime)" -ForegroundColor White
    
    # Show sample data
    if ($count -gt 0) {
        Write-Host
        Write-Host "📋 Sample data (first 3 records):" -ForegroundColor Yellow
        $sampleData = $peopleData | Select-Object -First 3 | ConvertTo-Json -Depth 2
        Write-Host $sampleData -ForegroundColor Gray
    }
    
    # Open file if requested
    if ($OpenFile) {
        Write-Host
        Write-Host "📂 Opening file..." -ForegroundColor Blue
        Start-Process $OutputFile
    }
    
    Write-Host
    Write-Host "✨ Data dump completed!" -ForegroundColor Green
    
} catch {
    Write-Host "❌ Error occurred:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    
    if ($_.Exception.Message -like "*Unable to connect*" -or $_.Exception.Message -like "*timeout*") {
        Write-Host
        Write-Host "💡 Troubleshooting tips:" -ForegroundColor Yellow
        Write-Host "   1. Make sure RestApiServer is running (run: .\run.bat)" -ForegroundColor White
        Write-Host "   2. Check if the server URL is correct: $ServerUrl" -ForegroundColor White
        Write-Host "   3. Verify the server is accessible in your browser" -ForegroundColor White
    }
    
    exit 1
}
