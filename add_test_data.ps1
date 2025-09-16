# Simple PowerShell script to add test people to RestApiServer
param(
    [string]$ServerUrl = "http://localhost:8080/people",
    [int]$Count = 1000
)

Write-Host "Adding $Count test people to RestApiServer..." -ForegroundColor Green

# Simple name arrays without special characters
$FirstNames = @(
    "Alejandro", "Maria", "Carlos", "Ana", "Jose", "Carmen", "Francisco", "Isabel",
    "Manuel", "David", "Pilar", "Daniel", "Teresa", "Javier", "Rosa", "Miguel",
    "Pablo", "Luis", "Laura", "Sergio", "Elena", "Jorge", "Sara", "Alberto",
    "Fernando", "Patricia", "Diego", "Lucia", "Ivan", "Cristina", "Oscar", "Nuria"
)

$LastNames = @(
    "Garcia", "Rodriguez", "Gonzalez", "Fernandez", "Lopez", "Martinez", "Sanchez", "Perez",
    "Gomez", "Martin", "Jimenez", "Ruiz", "Hernandez", "Diaz", "Moreno", "Munoz",
    "Alvarez", "Romero", "Alonso", "Gutierrez", "Navarro", "Torres", "Dominguez", "Vazquez",
    "Ramos", "Gil", "Ramirez", "Serrano", "Blanco", "Suarez", "Molina", "Morales"
)

function Get-RandomDNI {
    $number = Get-Random -Minimum 10000000 -Maximum 99999999
    $letters = @("A", "B", "C", "D", "E", "F", "G", "H", "J", "K", "L", "M", "N", "P", "Q", "R", "S", "T")
    $letter = $letters[(Get-Random -Maximum $letters.Length)]
    return "${number}${letter}"
}

$successCount = 0
$errorCount = 0

for ($i = 1; $i -le $Count; $i++) {
    $firstName = $FirstNames[(Get-Random -Maximum $FirstNames.Length)]
    $lastName1 = $LastNames[(Get-Random -Maximum $LastNames.Length)]
    $lastName2 = $LastNames[(Get-Random -Maximum $LastNames.Length)]
    
    $fullName = "$firstName $lastName1 $lastName2"
    $dni = Get-RandomDNI
    $age = Get-Random -Minimum 18 -Maximum 80
    
    $person = @{
        name = $fullName
        dni = $dni
        age = $age
    }
    
    $jsonBody = $person | ConvertTo-Json -Compress
    
    try {
        $response = Invoke-RestMethod -Uri $ServerUrl -Method POST -Body $jsonBody -ContentType "application/json" -TimeoutSec 5
        $successCount++
        
        if ($i % 100 -eq 0) {
            Write-Host "Progress: $i/$Count - Success: $successCount - Errors: $errorCount" -ForegroundColor Cyan
        }
    }
    catch {
        $errorCount++
        if ($i % 100 -eq 0) {
            Write-Host "Progress: $i/$Count - Success: $successCount - Errors: $errorCount" -ForegroundColor Yellow
        }
    }
    
    Start-Sleep -Milliseconds 5
}

Write-Host "Completed! Successfully added: $successCount people. Errors: $errorCount" -ForegroundColor Green

# Verify final count
try {
    $finalResponse = Invoke-RestMethod -Uri $ServerUrl -Method GET
    $totalCount = $finalResponse.Count
    Write-Host "Server now contains $totalCount people total." -ForegroundColor Green
}
catch {
    Write-Host "Could not verify final count." -ForegroundColor Yellow
}
