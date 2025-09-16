@echo off
setlocal enabledelayedexpansion

REM RestApiServer - Windows Startup Script
REM This script compiles and runs the RestApiServer application

echo 🚀 Starting RestApiServer...
echo =================================
echo.

REM Check if Java is installed
echo [INFO] Checking Java installation...
java -version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Java is not installed or not in PATH
    echo Please install Java 22 or higher and add it to your PATH
    pause
    exit /b 1
)

javac -version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Java compiler ^(javac^) is not installed or not in PATH
    echo Please install JDK 22 or higher and add it to your PATH
    pause
    exit /b 1
)

for /f "tokens=3" %%i in ('java -version 2^>^&1 ^| findstr "version"') do (
    set "java_version=%%i"
    set "java_version=!java_version:"=!"
)
echo [SUCCESS] Java version: !java_version!

REM Check if Maven is installed
echo [INFO] Checking Maven installation...
mvn -version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Maven is not installed or not in PATH
    echo Please install Maven 3.6+ and add it to your PATH
    pause
    exit /b 1
)

for /f "tokens=3" %%i in ('mvn -version 2^>^&1 ^| findstr "Maven"') do (
    set "mvn_version=%%i"
)
echo [SUCCESS] Maven version: !mvn_version!

REM Create target directories if they don't exist
echo [INFO] Setting up build directories...
if not exist "target\classes" mkdir "target\classes"
if not exist "target\dependency" mkdir "target\dependency"

REM Clean previous builds
echo [INFO] Cleaning previous builds...
del /q "target\classes\*" 2>nul
for /d %%i in ("target\classes\*") do rmdir /s /q "%%i" 2>nul

REM Compile with Maven
echo [INFO] Compiling project with Maven...
call mvn compile
if %errorlevel% neq 0 (
    echo [ERROR] Maven compilation failed
    pause
    exit /b 1
)
echo [SUCCESS] Maven compilation completed

REM Copy dependencies
echo [INFO] Copying dependencies...
call mvn dependency:copy-dependencies
if %errorlevel% neq 0 (
    echo [ERROR] Failed to copy dependencies
    pause
    exit /b 1
)
echo [SUCCESS] Dependencies copied

REM Compile Java sources manually
echo [INFO] Compiling Java sources...
javac -cp "target\classes;target\dependency\*" src\RestApiServer.java src\controller\PersonController.java src\service\PersonService.java src\repository\PersonRepository.java src\model\Person.java -d target\classes
if %errorlevel% neq 0 (
    echo [ERROR] Java compilation failed
    pause
    exit /b 1
)
echo [SUCCESS] Java compilation completed

REM Check if port 8080 is available
echo [INFO] Checking if port 8080 is available...
netstat -an | findstr ":8080" >nul 2>&1
if %errorlevel% equ 0 (
    echo [WARNING] Port 8080 appears to be in use
    echo [WARNING] Please stop any existing server or change the port
)

REM Display startup information
echo.
echo =================================
echo [SUCCESS] 🎉 RestApiServer Ready to Start!
echo =================================
echo.
echo 📋 Server Information:
echo    🌐 API Base URL: http://localhost:8080/people
echo    📱 Web Interface: Open index.html in your browser
echo    🔧 CORS: Enabled for all origins
echo    💾 Storage: In-memory ^(data will be lost on restart^)
echo.
echo 📖 Available Endpoints:
echo    GET    /people          - List all persons
echo    GET    /people/{dni}    - Get person by DNI
echo    POST   /people          - Create new person
echo    PUT    /people/{dni}    - Update person
echo    DELETE /people/{dni}    - Delete person
echo.
echo 🧪 Quick Test Commands:
echo    curl http://localhost:8080/people
echo    curl -X POST http://localhost:8080/people -H "Content-Type: application/json" -d "{\"name\":\"Test\",\"dni\":\"12345678A\",\"age\":25}"
echo.
echo ⏹️  To stop the server: Press Ctrl+C
echo =================================
echo.

REM Start the server
echo [INFO] Starting RestApiServer...
echo.

REM Run the server
java -cp "target\classes;target\dependency\*" RestApiServer

REM Pause on exit to see any error messages
if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Server exited with error code %errorlevel%
    pause
)
