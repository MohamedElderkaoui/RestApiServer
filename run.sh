#!/bin/bash

# RestApiServer - Startup Script
# This script compiles and runs the RestApiServer application

set -e  # Exit on any error

echo "🚀 Starting RestApiServer..."
echo "================================="

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Java is installed
print_status "Checking Java installation..."
if ! command -v java &> /dev/null; then
    print_error "Java is not installed or not in PATH"
    exit 1
fi

if ! command -v javac &> /dev/null; then
    print_error "Java compiler (javac) is not installed or not in PATH"
    exit 1
fi

java_version=$(java -version 2>&1 | head -n 1 | cut -d '"' -f 2)
print_success "Java version: $java_version"

# Check if Maven is installed
print_status "Checking Maven installation..."
if ! command -v mvn &> /dev/null; then
    print_error "Maven is not installed or not in PATH"
    exit 1
fi

mvn_version=$(mvn -version 2>&1 | head -n 1 | cut -d ' ' -f 3)
print_success "Maven version: $mvn_version"

# Create target directory if it doesn't exist
print_status "Setting up build directories..."
mkdir -p target/classes
mkdir -p target/dependency

# Clean previous builds
print_status "Cleaning previous builds..."
rm -rf target/classes/*

# Compile with Maven (downloads dependencies if needed)
print_status "Compiling project with Maven..."
if ! mvn compile; then
    print_error "Maven compilation failed"
    exit 1
fi
print_success "Maven compilation completed"

# Copy dependencies
print_status "Copying dependencies..."
if ! mvn dependency:copy-dependencies; then
    print_error "Failed to copy dependencies"
    exit 1
fi
print_success "Dependencies copied"

# Compile Java sources manually to ensure everything is up to date
print_status "Compiling Java sources..."
if ! javac -cp "target/classes:target/dependency/*" \
    src/RestApiServer.java \
    src/controller/PersonController.java \
    src/service/PersonService.java \
    src/repository/PersonRepository.java \
    src/model/Person.java \
    -d target/classes; then
    print_error "Java compilation failed"
    exit 1
fi
print_success "Java compilation completed"

# Check if server is already running on port 8080
print_status "Checking if port 8080 is available..."
if command -v netstat &> /dev/null; then
    if netstat -tuln | grep -q ':8080 '; then
        print_warning "Port 8080 appears to be in use"
        print_warning "Please stop any existing server or change the port"
    fi
elif command -v ss &> /dev/null; then
    if ss -tuln | grep -q ':8080 '; then
        print_warning "Port 8080 appears to be in use"
        print_warning "Please stop any existing server or change the port"
    fi
fi

# Display startup information
echo ""
echo "================================="
print_success "🎉 RestApiServer Ready to Start!"
echo "================================="
echo ""
echo "📋 Server Information:"
echo "   🌐 API Base URL: http://localhost:8080/people"
echo "   📱 Web Interface: Open index.html in your browser"
echo "   🔧 CORS: Enabled for all origins"
echo "   💾 Storage: In-memory (data will be lost on restart)"
echo ""
echo "📖 Available Endpoints:"
echo "   GET    /people          - List all persons"
echo "   GET    /people/{dni}    - Get person by DNI"
echo "   POST   /people          - Create new person"
echo "   PUT    /people/{dni}    - Update person"
echo "   DELETE /people/{dni}    - Delete person"
echo ""
echo "🧪 Quick Test Commands:"
echo "   curl http://localhost:8080/people"
echo "   curl -X POST http://localhost:8080/people -H 'Content-Type: application/json' -d '{\"name\":\"Test\",\"dni\":\"12345678A\",\"age\":25}'"
echo ""
echo "⏹️  To stop the server: Press Ctrl+C"
echo "================================="
echo ""

# Start the server
print_status "Starting RestApiServer..."
echo ""

# Run the server
java -cp "target/classes:target/dependency/*" RestApiServer
