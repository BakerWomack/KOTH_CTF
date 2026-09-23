#!/bin/bash

# OpenVPN Public Internet Configuration Script
# Compatible with Linux, macOS, and Windows (Git Bash/WSL)
# Usage: ./install_openvpn.sh -i <public_ip> -c <client_count> [-p <port>] [-o <output_dir>] [-d <docker_compose_file>]

set -e

# Detect operating system
detect_os() {
    case "$(uname -s)" in
        Linux*)     OS="Linux";;
        Darwin*)    OS="Mac";;
        CYGWIN*|MINGW*|MSYS*) OS="Windows";;
        *)          OS="Unknown";;
    esac
}

# Initialize OS detection
detect_os

# Default values
PORT="1194"
OUTPUT_DIR="./client_configs"
DOCKER_COMPOSE_FILE="./docker-compose.yml"
OVPN_DATA_DIR="./openvpn-server/openvpn-data"

# Platform-specific variables
if [[ "$OS" == "Windows" ]]; then
    # Windows paths and commands
    DOCKER_CMD="docker"
    COMPOSE_CMD="docker-compose"
    SUDO_CMD=""
    PATH_SEP="\\"
else
    # Linux/Mac paths and commands
    DOCKER_CMD="docker"
    COMPOSE_CMD="docker-compose"
    SUDO_CMD="sudo"
    PATH_SEP="/"
fi

# Function to display usage
usage() {
    echo "Usage: $0 -i <public_ip> -c <client_count> [-p <port>] [-o <output_dir>] [-d <docker_compose_file>]"
    echo ""
    echo "Required options:"
    echo "  -i <ip>                Address clients connect to (goes in the .ovpn 'remote' line):"
    echo "                         your server's public IP (with 1194/udp forwarded) or LAN IP;"
    echo "                         127.0.0.1 only for local single-host use. NOT 10.8.0.1."
    echo "  -c <client_count>      Number of client configuration files to generate"
    echo ""
    echo "Optional options:"
    echo "  -p <port>              OpenVPN port (default: 1194)"
    echo "  -o <output_dir>        Output directory for client configs (default: ./client_configs)"
    echo "  -d <docker_compose>    Docker compose file path (default: ./docker-compose.yml)"
    echo "  -h                     Show this help message"
    echo ""
    echo "Example (server reachable at 203.0.113.10):"
    echo "  $0 -i 203.0.113.10 -c 5 -p 1194 -o ./configs"
    echo "Example (local single-host testing):"
    echo "  $0 -i 127.0.0.1 -c 5"
    echo ""
    echo "Supported platforms: Linux, macOS, Windows (Git Bash/WSL)"
    echo "Current OS detected: $OS"
    exit 1
}

# Function to check if Docker is available and running
check_docker() {
    echo "Checking Docker availability..."
    
    if ! command -v docker &> /dev/null; then
        echo "Error: Docker is not installed or not in PATH"
        echo "Please install Docker Desktop from https://www.docker.com/products/docker-desktop"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        echo "Error: Docker is not running or not accessible"
        if [[ "$OS" == "Windows" ]]; then
            echo "Please start Docker Desktop and ensure it's running"
        elif [[ "$OS" == "Linux" ]]; then
            echo "Please start Docker service: sudo systemctl start docker"
        else
            echo "Please start Docker Desktop"
        fi
        exit 1
    fi
    
    echo "✓ Docker is available and running"
}

# Function to create directory (cross-platform)
create_directory() {
    local dir="$1"
    if [[ "$OS" == "Windows" ]]; then
        mkdir -p "$dir" 2>/dev/null || true
    else
        mkdir -p "$dir"
    fi
}

# Function to remove directory (cross-platform)
remove_directory() {
    local dir="$1"
    if [[ -d "$dir" ]]; then
        if [[ "$OS" == "Windows" ]]; then
            rm -rf "$dir" 2>/dev/null || true
        else
            $SUDO_CMD rm -rf "$dir"
        fi
    fi
}

# Function to get absolute path (cross-platform)
get_absolute_path() {
    local path="$1"
    if [[ "$OS" == "Windows" ]]; then
        # Convert to Windows-style path if needed
        echo "$(cd "$(dirname "$path")" && pwd)/$(basename "$path")" | sed 's|/|\\|g'
    else
        realpath "$path" 2>/dev/null || echo "$(cd "$(dirname "$path")" && pwd)/$(basename "$path")"
    fi
}

# Parse command line arguments
while getopts "i:c:p:o:d:h" opt; do
    case ${opt} in
        i )
            PUBLIC_IP="$OPTARG"
            ;;
        c )
            CLIENT_COUNT="$OPTARG"
            ;;
        p )
            PORT="$OPTARG"
            ;;
        o )
            OUTPUT_DIR="$OPTARG"
            ;;
        d )
            DOCKER_COMPOSE_FILE="$OPTARG"
            ;;
        h )
            usage
            ;;
        \? )
            echo "Invalid option: $OPTARG" 1>&2
            usage
            ;;
        : )
            echo "Invalid option: $OPTARG requires an argument" 1>&2
            usage
            ;;
    esac
done

# Check required arguments
if [[ -z "$PUBLIC_IP" || -z "$CLIENT_COUNT" ]]; then
    echo "Error: Public IP (-i) and client count (-c) are required"
    usage
fi

# Validate IP address format
if ! [[ $PUBLIC_IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    echo "Error: Invalid IP address format: $PUBLIC_IP"
    exit 1
fi

# Validate client count is a positive integer
if ! [[ $CLIENT_COUNT =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: Client count must be a positive integer"
    exit 1
fi

# Validate port is a number between 1-65535
if ! [[ $PORT =~ ^[1-9][0-9]*$ ]] || [ $PORT -gt 65535 ]; then
    echo "Error: Port must be a number between 1 and 65535"
    exit 1
fi

echo "=== OpenVPN Public Internet Configuration ==="
echo "Operating System: $OS"
echo "Public IP: $PUBLIC_IP"
echo "Client Count: $CLIENT_COUNT"
echo "Port: $PORT"
echo "Output Directory: $OUTPUT_DIR"
echo "Docker Compose File: $DOCKER_COMPOSE_FILE"
echo ""

# Check Docker availability
check_docker

# Create output directory
create_directory "$OUTPUT_DIR"

# Stop existing containers if running
echo "Stopping existing containers..."
if [ -f "$DOCKER_COMPOSE_FILE" ]; then
    $COMPOSE_CMD -f "$DOCKER_COMPOSE_FILE" down 2>/dev/null || true
fi

# Remove existing OpenVPN data if it exists
if [ -d "$OVPN_DATA_DIR" ]; then
    echo "Removing existing OpenVPN data..."
    remove_directory "$OVPN_DATA_DIR"
fi

# Create OpenVPN data directory
create_directory "$OVPN_DATA_DIR"

echo "Initializing OpenVPN configuration for $PUBLIC_IP:$PORT..."

# Get current working directory for volume mounting
CURRENT_DIR="$(pwd)"

# Initialize the OpenVPN configuration
# -s 10.8.0.0/24 : VPN client subnet (matches the return routes the CTF
#                  containers add via the openvpn server in their start.sh)
# -N            : NAT client traffic onto the CTF network (172.20.0.0/16)
# -d            : do NOT push a full-tunnel default route (don't hijack the
#                 client's internet; only route the CTF network)
# -p route ...  : push an explicit route into the CTF network so clients can
#                 reach challenge machines regardless of redirect-gateway
GENCONFIG_ARGS="-u udp://$PUBLIC_IP:$PORT -s 10.8.0.0/24 -N -d -p \"route 172.20.0.0 255.255.0.0\""
if [[ "$OS" == "Windows" ]]; then
    # Windows Docker volume mounting
    eval docker run -v "\"$CURRENT_DIR/$OVPN_DATA_DIR:/etc/openvpn\"" --rm kylemanna/openvpn ovpn_genconfig $GENCONFIG_ARGS
else
    # Linux/Mac Docker volume mounting
    eval docker run -v "\"$PWD/$OVPN_DATA_DIR:/etc/openvpn\"" --rm kylemanna/openvpn ovpn_genconfig $GENCONFIG_ARGS
fi

# OpenVPN 2.6+ with Data Channel Offload (DCO) refuses ANY compression
# directive and aborts the connection ("compression ... is not allowed since
# data-channel offloading is enabled"). The kylemanna image always writes
# comp-lzo, so strip every compression line from the generated server config.
# Run the edit inside the container since the file is root-owned.
if [[ "$OS" == "Windows" ]]; then
    docker run -v "$CURRENT_DIR/$OVPN_DATA_DIR:/etc/openvpn" --rm --entrypoint sh kylemanna/openvpn -c "sed -i '/comp-lzo/d;/compress/d' /etc/openvpn/openvpn.conf"
else
    docker run -v "$PWD/$OVPN_DATA_DIR:/etc/openvpn" --rm --entrypoint sh kylemanna/openvpn -c "sed -i '/comp-lzo/d;/compress/d' /etc/openvpn/openvpn.conf"
fi

# Generate the certificate authority
echo "Generating certificate authority (this may take a moment)..."
if [[ "$OS" == "Windows" ]]; then
    # Windows Docker volume mounting - completely non-interactive
    echo -e "\n\n\n\n\n\n\n" | docker run -v "$CURRENT_DIR/$OVPN_DATA_DIR:/etc/openvpn" --rm -i kylemanna/openvpn ovpn_initpki nopass
else
    # Linux/Mac Docker volume mounting - completely non-interactive
    echo -e "\n\n\n\n\n\n\n" | docker run -v "$PWD/$OVPN_DATA_DIR:/etc/openvpn" --rm -i kylemanna/openvpn ovpn_initpki nopass
fi

# ovpn_genconfig (above) already wrote a correct ovpn_env.sh and openvpn.conf
# into $OVPN_DATA_DIR, with the remote set to the -i address, NAT enabled, and
# the CTF route pushed. No hand-written overrides needed here -- doing so was
# the original bug (the override was written to a path the container never
# mounted, so it silently had no effect).

# Generate client certificates and configuration files
echo "Generating $CLIENT_COUNT client configuration files..."
for i in $(seq 1 $CLIENT_COUNT); do
    CLIENT_NAME="client$i"
    echo "Generating client certificate for $CLIENT_NAME..."
    
    # Generate client certificate (cross-platform)
    if [[ "$OS" == "Windows" ]]; then
        # Windows - non-interactive mode
        echo -e "\n\n\n\n\n\n\n" | docker run -v "$CURRENT_DIR/$OVPN_DATA_DIR:/etc/openvpn" --rm -i kylemanna/openvpn easyrsa build-client-full $CLIENT_NAME nopass
    else
        # Linux/Mac - non-interactive mode
        echo -e "\n\n\n\n\n\n\n" | docker run -v "$PWD/$OVPN_DATA_DIR:/etc/openvpn" --rm -i kylemanna/openvpn easyrsa build-client-full $CLIENT_NAME nopass
    fi
    
    # Generate client configuration file (cross-platform)
    echo "Creating configuration file for $CLIENT_NAME..."
    if [[ "$OS" == "Windows" ]]; then
        docker run -v "$CURRENT_DIR/$OVPN_DATA_DIR:/etc/openvpn" --rm kylemanna/openvpn ovpn_getclient $CLIENT_NAME > "$OUTPUT_DIR/$CLIENT_NAME.ovpn"
    else
        docker run -v "$PWD/$OVPN_DATA_DIR:/etc/openvpn" --rm kylemanna/openvpn ovpn_getclient $CLIENT_NAME > "$OUTPUT_DIR/$CLIENT_NAME.ovpn"
    fi
    
    echo "✓ Generated $CLIENT_NAME.ovpn"
done


echo ""
echo "=== Configuration Complete ==="
echo "✓ OpenVPN server configured for $PUBLIC_IP:$PORT"
echo "✓ Generated $CLIENT_COUNT client configuration files in $OUTPUT_DIR/"
echo "✓ Updated Docker Compose configuration"
echo "✓ Operating System: $OS"
echo ""
echo "Next steps:"
echo "1. Make sure port $PORT/UDP is open in your firewall"
if [[ "$OS" == "Windows" ]]; then
    echo "2. Start the OpenVPN server: docker-compose up -d"
else
    echo "2. Start the OpenVPN server: docker-compose up -d"
fi
echo "3. Distribute the client .ovpn files to your users"
echo ""
echo "Client configuration files:"
if [[ "$OS" == "Windows" ]]; then
    ls "$OUTPUT_DIR"/*.ovpn 2>/dev/null | sed 's/.*[\/\\]//g' | sed 's/^/  - /' || echo "  - Check $OUTPUT_DIR for .ovpn files"
else
    ls -1 "$OUTPUT_DIR"/*.ovpn 2>/dev/null | sed 's/.*\///g' | sed 's/^/  - /' || echo "  - Check $OUTPUT_DIR for .ovpn files"
fi
echo ""
if [[ "$OS" == "Windows" ]]; then
    echo "Platform Notes:"
    echo "- Running on Windows: $OS"
    echo "- Use Git Bash or WSL for best compatibility"
    echo "- Make sure Docker Desktop is running"
fi
