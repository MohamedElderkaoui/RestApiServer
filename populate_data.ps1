# PowerShell script to populate RestApiServer with 1000 test people
# Usage: .\populate_data.ps1

param(
    [string]$ServerUrl = "http://localhost:8080/people",
    [int]$Count = 1000,
    [int]$BatchSize = 50,
    [switch]$ShowProgress = $true
)

Write-Host "🚀 Starting data population for RestApiServer" -ForegroundColor Green
Write-Host "=================================" -ForegroundColor Cyan
Write-Host "Server URL: $ServerUrl" -ForegroundColor Yellow
Write-Host "Total People: $Count" -ForegroundColor Yellow
Write-Host "Batch Size: $BatchSize" -ForegroundColor Yellow
Write-Host "=================================" -ForegroundColor Cyan
Write-Host

# Spanish names for realistic data
$FirstNames = @(
    "Alejandro", "María", "Carlos", "Ana", "José", "Carmen", "Francisco", "Isabel", 
    "Manuel", "Dolores", "David", "Pilar", "Daniel", "Teresa", "Javier", "Rosa",
    "Miguel", "Antonia", "Pablo", "Francisca", "Luis", "Laura", "Sergio", "Elena",
    "Jorge", "Sara", "Alberto", "Silvia", "Fernando", "Patricia", "Diego", "Lucía",
    "Iván", "Cristina", "Rubén", "Marta", "Óscar", "Nuria", "Adrián", "Susana",
    "Raúl", "Eva", "Álvaro", "Beatriz", "Víctor", "Natalia", "Gonzalo", "Andrea",
    "Rafael", "Lorena", "Marcos", "Rocío", "Antonio", "Mónica", "Jesús", "Alicia",
    "Eduardo", "Sandra", "Ángel", "Raquel", "Roberto", "Verónica", "Pedro", "Julia",
    "Ramón", "Irene", "Emilio", "Sonia", "Tomás", "Gloria", "Ignacio", "Amparo"
)

$LastNames = @(
    "García", "Rodríguez", "González", "Fernández", "López", "Martínez", "Sánchez", "Pérez",
    "Gómez", "Martín", "Jiménez", "Ruiz", "Hernández", "Díaz", "Moreno", "Muñoz",
    "Álvarez", "Romero", "Alonso", "Gutiérrez", "Navarro", "Torres", "Domínguez", "Vázquez",
    "Ramos", "Gil", "Ramírez", "Serrano", "Blanco", "Suárez", "Molina", "Morales",
    "Ortega", "Delgado", "Castro", "Ortiz", "Rubio", "Marín", "Sanz", "Iglesias",
    "Medina", "Garrido", "Cortés", "Castillo", "Santos", "Lozano", "Guerrero", "Cano",
    "Prieto", "Méndez", "Cruz", "Herrera", "Peña", "Flores", "Cabrera", "Aguilar"
)

# Function to generate a random Spanish DNI
function Get-RandomDNI {
    $number = Get-Random -Minimum 10000000 -Maximum 99999999
    $letters = @("A", "B", "C", "D", "E", "F", "G", "H", "J", "K", "L", "M", "N", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z")
    $letter = $letters[(Get-Random -Maximum $letters.Length)]
    return "${number}${letter}"
}

# Function to generate a random person
function Get-RandomPerson {
    $firstName = $FirstNames[(Get-Random -Maximum $FirstNames.Length)]
    $lastName1 = $LastNames[(Get-Random -Maximum $LastNames.Length)]
    $lastName2 = $LastNames[(Get-Random -Maximum $LastNames.Length)]
    
    # Ensure last names are different
    while ($lastName1 -eq $lastName2) {
        $lastName2 = $LastNames[(Get-Random -Maximum $LastNames.Length)]
    }
    
    $fullName = "$firstName $lastName1 $lastName2"
    $dni = Get-RandomDNI
    $age = Get-Random -Minimum 18 -Maximum 85
    
    return @{
        name = $fullName
        dni = $dni
        age = $age
    }
}

# Check if server is running
Write-Host "🔍 Checking server availability..." -ForegroundColor Blue
try {
    $response = Invoke-RestMethod -Uri $ServerUrl -Method GET -TimeoutSec 5
    Write-Host "✅ Server is running and accessible" -ForegroundColor Green
} catch {
    Write-Host "❌ Error: Cannot connect to server at $ServerUrl" -ForegroundColor Red
    Write-Host "Please make sure RestApiServer is running first." -ForegroundColor Yellow
    Write-Host "Run: .\run.bat or .\run.sh" -ForegroundColor Yellow
    exit 1
}

Write-Host

# Initialize counters
$successCount = 0
$errorCount = 0
$duplicateCount = 0
$usedDNIs = @{}

# Create progress tracking
$batches = [math]::Ceiling($Count / $BatchSize)
$currentBatch = 0

Write-Host "📊 Starting data generation and upload..." -ForegroundColor Blue
Write-Host

for ($i = 1; $i -le $Count; $i++) {
    try {
        # Generate unique person
        do {
            $person = Get-RandomPerson
        } while ($usedDNIs.ContainsKey($person.dni))
        
        $usedDNIs[$person.dni] = $true
        
        # Convert to JSON
        $jsonBody = $person | ConvertTo-Json -Compress
        
        # Make POST request
        $response = Invoke-RestMethod -Uri $ServerUrl -Method POST -Body $jsonBody -ContentType "application/json" -TimeoutSec 10
        
        $successCount++
        
        # Show progress
        if ($ShowProgress -and ($i % $BatchSize -eq 0 -or $i -eq $Count)) {
            $currentBatch++
            $percentage = [math]::Round(($i / $Count) * 100, 1)
            Write-Host "📈 Progress: $i/$Count ($percentage%) | ✅ Success: $successCount | ❌ Errors: $errorCount" -ForegroundColor Cyan
        }
        
    } catch {
        $errorCount++
        
        # Check if it's a duplicate DNI error (409 Conflict)
        if ($_.Exception.Response.StatusCode -eq 409) {
            $duplicateCount++
            Write-Host "⚠️  Duplicate DNI detected: $($person.dni) - Retrying..." -ForegroundColor Yellow
            $i-- # Retry this iteration
            continue
        }
        
        Write-Host "❌ Error creating person $i`: $($_.Exception.Message)" -ForegroundColor Red
        
        # Add small delay on error to avoid overwhelming server
        Start-Sleep -Milliseconds 100
    }
    
    # Small delay between requests to avoid overwhelming server
    Start-Sleep -Milliseconds 10
}

Write-Host
Write-Host "🎉 Data population completed!" -ForegroundColor Green
Write-Host "=================================" -ForegroundColor Cyan
Write-Host "📊 Final Statistics:" -ForegroundColor Yellow
Write-Host "   ✅ Successfully created: $successCount people" -ForegroundColor Green
Write-Host "   ❌ Errors encountered: $errorCount" -ForegroundColor Red
Write-Host "   🔄 Duplicate DNIs: $duplicateCount" -ForegroundColor Yellow
Write-Host "   🎯 Success rate: $([math]::Round(($successCount / $Count) * 100, 2))%" -ForegroundColor Cyan
Write-Host

# Verify final count
Write-Host "🔍 Verifying data on server..." -ForegroundColor Blue
try {
    $finalResponse = Invoke-RestMethod -Uri $ServerUrl -Method GET
    $actualCount = $finalResponse.Count
    Write-Host "✅ Server now contains $actualCount people" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Could not verify final count on server" -ForegroundColor Yellow
}

Write-Host
Write-Host "🚀 You can now test the populated server:" -ForegroundColor Cyan
Write-Host "   📱 Web Interface: Open index.html in your browser" -ForegroundColor White
Write-Host "   🌐 API Endpoint: $ServerUrl" -ForegroundColor White
Write-Host "   🔍 Search: Try searching for names like 'María', 'García', etc." -ForegroundColor White
Write-Host

Write-Host "✨ Data population script completed successfully!" -ForegroundColor Green
