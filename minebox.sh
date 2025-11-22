#!/data/data/com.termux/files/usr/bin/bash
# Minecraft Bedrock Server Install + Offline Mode + Box64 Execution
VERSION="1.21.93.1"
PLATFORM="linux"
SHARED_DIR="/data/data/com.termux/files/usr/tmp/bds_shared"
SETUP_FLAG="$SHARED_DIR/.initial_setup_done"

mkdir -p "$SHARED_DIR"
cd "$SHARED_DIR" || exit 1

# ───────────────────────────────
# Download & Extract
# ───────────────────────────────
JSON_URL="https://raw.githubusercontent.com/Bedrock-OSS/BDS-Versions/main/${PLATFORM}/${VERSION}.json"

echo "[+] Fetching version info..."
JSON_DATA=$(curl -s "$JSON_URL")
DOWNLOAD_URL=$(echo "$JSON_DATA" | jq -r '.download_url')
FILENAME=$(basename "$DOWNLOAD_URL")

if [ ! -f "$SHARED_DIR/bedrock_server" ]; then
    if [ ! -f "$FILENAME" ]; then
        echo "[+] Downloading → $FILENAME"
        wget -O "$FILENAME" "$DOWNLOAD_URL" || { echo "[✘] Download failed!"; exit 1; }
    fi
    echo "[+] Extracting..."
    unzip -o "$FILENAME" -d "$SHARED_DIR"
else
    echo "[i] Bedrock Server already exists → skipping download/extract"
fi

# ───────────────────────────────
# First-run: Generate server.properties
# ───────────────────────────────
PROPS_FILE="$SHARED_DIR/server.properties"

if [ ! -f "$SETUP_FLAG" ]; then
    echo "====== Minecraft Bedrock Server Initial Setup ======"

    # Function: prompt input with default
    ask() {
        local prompt="$1"
        local default="$2"
        read -p "$prompt [$default]: " input
        echo "${input:-$default}"
    }

    SERVER_NAME=$(ask "Server Name" "Usual Server")
    DIFFICULTY=$(ask "Difficulty (peaceful/easy/normal/hard)" "easy")
    MAX_PLAYERS=$(ask "Max Players" "30")
    GAMEMODE=$(ask "Game Mode (survival/creative/adventure)" "survival")
    LEVEL_NAME=$(ask "World Name" "Bedrock level")
    LEVEL_SEED=$(ask "World Seed (optional)" "")

    # Summary
    echo -e "\n[i] Configuration Summary:"
    echo "Server Name   : $SERVER_NAME"
    echo "Difficulty    : $DIFFICULTY"
    echo "Max Players   : $MAX_PLAYERS"
    echo "Game Mode     : $GAMEMODE"
    echo "World Name    : $LEVEL_NAME"
    echo "World Seed    : $LEVEL_SEED"

    read -p "Proceed with these settings? (Y/n) " CONFIRM
    CONFIRM=${CONFIRM:-Y}

    if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo "[+] Generating server.properties..."
        cat > "$PROPS_FILE" <<EOF
server-name=$SERVER_NAME
gamemode=$GAMEMODE
force-gamemode=false
difficulty=$DIFFICULTY
allow-cheats=true
max-players=$MAX_PLAYERS
online-mode=false
allow-list=false
server-port=19132
server-portv6=19133
enable-lan-visibility=true
view-distance=16
tick-distance=4
player-idle-timeout=0
max-threads=8
level-name=$LEVEL_NAME
level-seed=$LEVEL_SEED
default-player-permission-level=member
texturepack-required=false
content-log-file-enabled=false
compression-threshold=1
compression-algorithm=zlib
server-authoritative-movement-strict=false
server-authoritative-dismount-strict=false
server-authoritative-entity-interactions-strict=false
player-position-acceptance-threshold=0.5
player-movement-action-direction-threshold=0.85
server-authoritative-block-breaking-pick-range-scalar=1.5
chat-restriction=None
disable-player-interaction=false
client-side-chunk-generation-enabled=true
block-network-ids-are-hashes=true
disable-persona=false
disable-custom-skins=false
server-build-radius-ratio=Disabled
allow-outbound-script-debugging=false
allow-inbound-script-debugging=false
script-debugger-auto-attach=disabled
EOF
        touch "$SETUP_FLAG"
        echo "[i] Initial setup complete!"
    else
        echo "[!] Setup cancelled. Please run the script again."
        exit 0
    fi
else
    echo "[i] Initial setup already done → keeping existing server.properties"
fi

# ───────────────────────────────
# Run Bedrock Server via Box64 in Ubuntu(Proot)
# ───────────────────────────────
echo "[+] Launching Bedrock Server via Box64 in Ubuntu(Proot)..."

proot-distro login ubuntu --shared-tmp <<EOF
export BOX64_DYNAREC_STRONGMEM=1
export BOX64_DYNAREC_SAFEFLAGS=1
export BOX64_DYNAREC_FASTROUND=0
export BOX64_DYNAREC_CALLRET=0
export BOX64_NOBANNER=1

if ! command -v box64 &> /dev/null; then
    echo "[+] Installing Box64..."
    sudo dpkg --add-architecture armhf
    sudo apt update
    sudo apt install -y box64
fi

clear
BDS_DIR="/tmp/bds_shared"
cd "\$BDS_DIR" || exit 1
chmod +x ./bedrock_server
BOX64_LD_LIBRARY_PATH="\$BDS_DIR" box64 ./bedrock_server
EOF
