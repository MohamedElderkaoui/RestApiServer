#!/bin/bash

# Bash script to populate RestApiServer with 1000 test people
# Usage: ./populate_data.sh [count] [server_url]

set -e

# Default parameters
SERVER_URL="${2:-http://localhost:8080/people}"
COUNT="${1:-1000}"
BATCH_SIZE=50

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Starting data population for RestApiServer${NC}"
echo -e "${CYAN}=================================${NC}"
echo -e "${YELLOW}Server URL: $SERVER_URL${NC}"
echo -e "${YELLOW}Total People: $COUNT${NC}"
echo -e "${YELLOW}Batch Size: $BATCH_SIZE${NC}"
echo -e "${CYAN}=================================${NC}"
echo

# Spanish names arrays
FIRST_NAMES=(
    "Alejandro" "María" "Carlos" "Ana" "José" "Carmen" "Francisco" "Isabel"
    "Manuel" "Dolores" "David" "Pilar" "Daniel" "Teresa" "Javier" "Rosa"
    "Miguel" "Antonia" "Pablo" "Francisca" "Luis" "Laura" "Sergio" "Elena"
    "Jorge" "Sara" "Alberto" "Silvia" "Fernando" "Patricia" "Diego" "Lucía"
    "Iván" "Cristina" "Rubén" "Marta" "Óscar" "Nuria" "Adrián" "Susana"
    "Raúl" "Eva" "Álvaro" "Beatriz" "Víctor" "Natalia" "Gonzalo" "Andrea"
    "Rafael" "Lorena" "Marcos" "Rocío" "Antonio" "Mónica" "Jesús" "Alicia"
    "Eduardo" "Sandra" "Ángel" "Raquel" "Roberto" "Verónica" "Pedro" "Julia"
    "Ramón" "Irene" "Emilio" "Sonia" "Tomás" "Gloria" "Ignacio" "Amparo"
)

LAST_NAMES=(
    "García" "Rodríguez" "González" "Fernández" "López" "Martínez" "Sánchez" "Pérez"
    "Gómez" "Martín" "Jiménez" "Ruiz" "Hernández" "Díaz" "Moreno" "Muñoz"
    "Álvarez" "Romero" "Alonso" "Gutiérrez" "Navarro" "Torres" "Domínguez" "Vázquez"
    "Ramos" "Gil" "Ramírez" "Serrano" "Blanco" "Suárez" "Molina" "Morales"
    "Ortega" "Delgado" "Castro" "Ortiz" "Rubio" "Marín" "Sanz" "Iglesias"
    "Medina" "Garrido" "Cortés" "Castillo" "Santos" "Lozano" "Guerrero" "Cano"
    "Prieto" "Méndez" "Cruz" "Herrera" "Peña" "Flores" "Cabrera" "Aguilar"
)

# Function to generate random DNI
generate_dni() {
    local number=$(shuf -i 10000000-99999999 -n 1)
    local letters=("A" "B" "C" "D" "E" "F" "G" "H" "J" "K" "L" "M" "N" "P" "Q" "R" "S" "T" "U" "V" "W" "X" "Y" "Z")
    local letter=${letters[$RANDOM % ${#letters[@]}]}
    echo "${number}${letter}"
}

# Function to generate random person
generate_person() {
    local first_name=${FIRST_NAMES[$RANDOM % ${#FIRST_NAMES[@]}]}
    local last_name1=${LAST_NAMES[$RANDOM % ${#LAST_NAMES[@]}]}
    local last_name2=${LAST_NAMES[$RANDOM % ${#LAST_NAMES[@]}]}
    
    # Ensure last names are different
    while [ "$last_name1" = "$last_name2" ]; do
        last_name2=${LAST_NAMES[$RANDOM % ${#LAST_NAMES[@]}]}
    done
    
    local full_name="$first_name $last_name1 $last_name2"
    local dni=$(generate_dni)
    local age=$(shuf -i 18-85 -n 1)
    
    echo "{\"name\":\"$full_name\",\"dni\":\"$dni\",\"age\":$age}"
}

# Check if server is running
echo -e "${BLUE}🔍 Checking server availability...${NC}"
if ! curl -s -f "$SERVER_URL" > /dev/null 2>&1; then
    echo -e "${RED}❌ Error: Cannot connect to server at $SERVER_URL${NC}"
    echo -e "${YELLOW}Please make sure RestApiServer is running first.${NC}"
    echo -e "${YELLOW}Run: ./run.sh or ./run.bat${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Server is running and accessible${NC}"
echo

# Initialize counters
success_count=0
error_count=0
duplicate_count=0
declare -A used_dnis

echo -e "${BLUE}📊 Starting data generation and upload...${NC}"
echo

# Main loop
for ((i=1; i<=COUNT; i++)); do
    # Generate unique person
    while true; do
        person_json=$(generate_person)
        dni=$(echo "$person_json" | grep -o '"dni":"[^"]*"' | cut -d'"' -f4)
        
        if [[ -z "${used_dnis[$dni]}" ]]; then
            used_dnis[$dni]=1
            break
        fi
    done
    
    # Make POST request
    response=$(curl -s -w "%{http_code}" -X POST "$SERVER_URL" \
        -H "Content-Type: application/json" \
        -d "$person_json" \
        --connect-timeout 10 \
        --max-time 30)
    
    http_code="${response: -3}"
    
    if [[ "$http_code" -eq 201 ]]; then
        ((success_count++))
    elif [[ "$http_code" -eq 409 ]]; then
        ((duplicate_count++))
        echo -e "${YELLOW}⚠️  Duplicate DNI detected: $dni - Retrying...${NC}"
        ((i--)) # Retry this iteration
        continue
    else
        ((error_count++))
        echo -e "${RED}❌ Error creating person $i: HTTP $http_code${NC}"
        sleep 0.1 # Small delay on error
    fi
    
    # Show progress
    if ((i % BATCH_SIZE == 0 || i == COUNT)); then
        percentage=$(echo "scale=1; $i * 100 / $COUNT" | bc -l)
        echo -e "${CYAN}📈 Progress: $i/$COUNT ($percentage%) | ✅ Success: $success_count | ❌ Errors: $error_count${NC}"
    fi
    
    # Small delay between requests
    sleep 0.01
done

echo
echo -e "${GREEN}🎉 Data population completed!${NC}"
echo -e "${CYAN}=================================${NC}"
echo -e "${YELLOW}📊 Final Statistics:${NC}"
echo -e "${GREEN}   ✅ Successfully created: $success_count people${NC}"
echo -e "${RED}   ❌ Errors encountered: $error_count${NC}"
echo -e "${YELLOW}   🔄 Duplicate DNIs: $duplicate_count${NC}"

if ((COUNT > 0)); then
    success_rate=$(echo "scale=2; $success_count * 100 / $COUNT" | bc -l)
    echo -e "${CYAN}   🎯 Success rate: $success_rate%${NC}"
fi
echo

# Verify final count
echo -e "${BLUE}🔍 Verifying data on server...${NC}"
if final_response=$(curl -s -f "$SERVER_URL" 2>/dev/null); then
    actual_count=$(echo "$final_response" | jq '. | length' 2>/dev/null || echo "unknown")
    echo -e "${GREEN}✅ Server now contains $actual_count people${NC}"
else
    echo -e "${YELLOW}⚠️  Could not verify final count on server${NC}"
fi

echo
echo -e "${CYAN}🚀 You can now test the populated server:${NC}"
echo -e "   📱 Web Interface: Open index.html in your browser"
echo -e "   🌐 API Endpoint: $SERVER_URL"
echo -e "   🔍 Search: Try searching for names like 'María', 'García', etc."
echo

echo -e "${GREEN}✨ Data population script completed successfully!${NC}"
