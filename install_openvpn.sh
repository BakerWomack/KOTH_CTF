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
    echo "  -i <public_ip>         Public IP address for the OpenVPN server (use 10.8.0.1 for VPN network)"
    echo "  -c <client_count>      Number of client configuration files to generate"
    echo ""
    echo "Optional options:"
    echo "  -p <port>              OpenVPN port (default: 1194)"
    echo "  -o <output_dir>        Output directory for client configs (default: ./client_configs)"
    echo "  -d <docker_compose>    Docker compose file path (default: ./docker-compose.yml)"
    echo "  -h                     Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 -i 127.0.0.1 -c 5 -p 1194 -o ./configs"
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
if [[ "$OS" == "Windows" ]]; then
    # Windows Docker volume mounting
    docker run -v "$CURRENT_DIR/$OVPN_DATA_DIR:/etc/openvpn" --rm kylemanna/openvpn ovpn_genconfig -u udp://$PUBLIC_IP:$PORT
else
    # Linux/Mac Docker volume mounting
    docker run -v "$PWD/$OVPN_DATA_DIR:/etc/openvpn" --rm kylemanna/openvpn ovpn_genconfig -u udp://$PUBLIC_IP:$PORT
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

# Update the ovpn_env.sh file with the new configuration
echo "Updating OpenVPN environment configuration..."
cat > "$OVPN_DATA_DIR/ovpn_env.sh" << EOF
declare -x OVPN_AUTH=
declare -x OVPN_CIPHER=
declare -x OVPN_CLIENT_TO_CLIENT=
declare -x OVPN_CN=$PUBLIC_IP
declare -x OVPN_COMP_LZO=0
declare -x OVPN_DEFROUTE=1
declare -x OVPN_DEVICE=tun
declare -x OVPN_DEVICEN=0
declare -x OVPN_DISABLE_PUSH_BLOCK_DNS=0
declare -x OVPN_DNS=1
declare -x OVPN_DNS_SERVERS=([0]="8.8.8.8" [1]="8.8.4.4")
declare -x OVPN_ENV=/etc/openvpn/ovpn_env.sh
declare -x OVPN_EXTRA_CLIENT_CONFIG=()
declare -x OVPN_EXTRA_SERVER_CONFIG=()
declare -x OVPN_FRAGMENT=
declare -x OVPN_KEEPALIVE='10 60'
declare -x OVPN_MTU=
declare -x OVPN_NAT=1
declare -x OVPN_PORT=$PORT
declare -x OVPN_PROTO=udp
declare -x OVPN_PUSH=([0]="route 172.20.0.0 255.255.0.0")
declare -x OVPN_ROUTES=()
declare -x OVPN_SERVER=10.8.0.0/24
declare -x OVPN_SERVER_CN=localhost
declare -x OVPN_SERVER_URL=udp://$PUBLIC_IP:$PORT
declare -x OVPN_TLS_CIPHER=
EOF

# Update the OpenVPN server configuration
echo "Updating OpenVPN server configuration..."
cat > "$OVPN_DATA_DIR/openvpn.conf" << EOF
server 10.8.0.0 255.255.255.0
verb 3
key /etc/openvpn/pki/private/$PUBLIC_IP.key
ca /etc/openvpn/pki/ca.crt
cert /etc/openvpn/pki/issued/$PUBLIC_IP.crt
dh /etc/openvpn/pki/dh.pem
tls-auth /etc/openvpn/pki/ta.key
key-direction 0
keepalive 10 60
persist-key
persist-tun

proto udp
port $PORT
dev tun0
status /tmp/openvpn-status.log

user nobody
group nogroup
comp-lzo no

### Route Configurations Below
# CTF machines are on 172.20.0.0/16, directly connected to this container via
# eth0 and reached by masquerade (OVPN_NAT=1), so no server-side route needed.

### Push Configurations Below
push "block-outside-dns"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
push "comp-lzo no"
# Route clients into the CTF network so they can reach challenge machines.
# This does not depend on redirect-gateway applying on the client.
push "route 172.20.0.0 255.255.0.0"
EOF

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

# Copy OpenVPN data to the server directory
echo "Copying OpenVPN data to server directory..."
cp -r "$OVPN_DATA_DIR"/* "./openvpn-server/openvpn-data/" 2>/dev/null || true

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
