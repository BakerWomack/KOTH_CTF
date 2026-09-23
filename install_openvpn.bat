@echo off
REM OpenVPN Installation Script for Windows (Simplified)
REM This batch file provides an alternative for Windows users without Git Bash
REM Requires Docker Desktop to be installed and running

REM Check if help is requested
if "%1"=="-h" goto show_usage
if "%1"=="/?" goto show_usage

REM Parse arguments
set PUBLIC_IP=
set CLIENT_COUNT=
set PORT=1194
set OUTPUT_DIR=.\client_configs

:parse_args
if "%1"=="" goto check_required
if "%1"=="-i" (
    set PUBLIC_IP=%2
    shift
    shift
    goto parse_args
)
if "%1"=="-c" (
    set CLIENT_COUNT=%2
    shift
    shift
    goto parse_args
)
if "%1"=="-p" (
    set PORT=%2
    shift
    shift
    goto parse_args
)
if "%1"=="-o" (
    set OUTPUT_DIR=%2
    shift
    shift
    goto parse_args
)
echo Unknown option: %1
goto show_usage

:check_required
if "%PUBLIC_IP%"=="" (
    echo Error: Public IP address is required
    goto show_usage
)
if "%CLIENT_COUNT%"=="" (
    echo Error: Client count is required
    goto show_usage
)

REM Validate client count is numeric
set /a test_count=%CLIENT_COUNT% 2>nul
if %test_count% LEQ 0 (
    echo Error: Client count must be a positive number
    goto show_usage
)

echo === OpenVPN Windows Installation ===
echo Public IP: %PUBLIC_IP%
echo Client Count: %CLIENT_COUNT%
echo Port: %PORT%
echo Output Directory: %OUTPUT_DIR%
echo.

REM Check Docker
docker --version >nul 2>&1
if errorlevel 1 (
    echo Error: Docker not found. Please install Docker Desktop.
    exit /b 1
)

docker info >nul 2>&1
if errorlevel 1 (
    echo Error: Docker is not running. Please start Docker Desktop.
    exit /b 1
)

echo Docker is running...

REM Create directories
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"
if not exist "openvpn-server" mkdir "openvpn-server"
if not exist "openvpn-server\openvpn-data" mkdir "openvpn-server\openvpn-data"

REM Clean existing data
if exist "openvpn-server\openvpn-data" rmdir /s /q "openvpn-server\openvpn-data" >nul 2>&1
mkdir "openvpn-server\openvpn-data"

echo Initializing OpenVPN for %PUBLIC_IP%:%PORT%...

REM Initialize OpenVPN
docker run -v "%cd%\openvpn-server\openvpn-data:/etc/openvpn" --rm kylemanna/openvpn ovpn_genconfig -u udp://%PUBLIC_IP%:%PORT% -s 10.8.0.0/24 -N -d -p "route 172.20.0.0 255.255.0.0"
if errorlevel 1 (
    echo Error: Failed to initialize OpenVPN configuration
    exit /b 1
)

REM OpenVPN 2.6+ with DCO rejects any compression directive; strip comp-lzo
REM so modern clients don't fail with "compression ... is not allowed".
docker run -v "%cd%\openvpn-server\openvpn-data:/etc/openvpn" --rm --entrypoint sh kylemanna/openvpn -c "sed -i '/comp-lzo/d;/compress/d' /etc/openvpn/openvpn.conf"

REM Generate CA
echo Generating certificate authority...
echo. | docker run -v "%cd%\openvpn-server\openvpn-data:/etc/openvpn" --rm -i kylemanna/openvpn ovpn_initpki nopass
if errorlevel 1 (
    echo Error: Failed to generate certificate authority
    exit /b 1
)

REM Generate client certificates
echo Generating client certificates...
set /a counter=1
:client_loop
if %counter% GTR %CLIENT_COUNT% goto clients_done

echo Creating client%counter%...
echo. | docker run -v "%cd%\openvpn-server\openvpn-data:/etc/openvpn" --rm -i kylemanna/openvpn easyrsa build-client-full client%counter% nopass
if errorlevel 1 (
    echo Warning: Failed to generate client%counter% certificate
) else (
    docker run -v "%cd%\openvpn-server\openvpn-data:/etc/openvpn" --rm kylemanna/openvpn ovpn_getclient client%counter% > "%OUTPUT_DIR%\client%counter%.ovpn"
    echo Generated: client%counter%.ovpn
)

set /a counter=%counter%+1
goto client_loop

:clients_done
echo.
echo === Configuration Complete ===
echo Server IP: %PUBLIC_IP%:%PORT%
echo Generated %CLIENT_COUNT% client configs in %OUTPUT_DIR%\
echo.
echo Next steps:
echo 1. Open firewall port %PORT%/UDP
echo 2. Start server: docker-compose up -d
echo 3. Distribute .ovpn files to clients
echo.
goto end

:show_usage
echo.
echo OpenVPN Installation Script for Windows
echo Usage: %0 -i [IP] -c [count] [-p [port]] [-o [output_dir]]
echo.
echo Required:
echo   -i [IP]       Address clients connect to (the .ovpn "remote" line):
echo                 your server's public IP (with 1194/udp forwarded) or LAN IP;
echo                 127.0.0.1 only for local single-host use. NOT 10.8.0.1.
echo   -c [count]    Number of client configs
echo.
echo Optional:
echo   -p [port]     Port (default: 1194)
echo   -o [dir]      Output directory (default: .\client_configs)
echo   -h            Show this help
echo.
echo Example: %0 -i 203.0.113.10 -c 5
echo.

:end
