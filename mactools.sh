#!/usr/bin/env bash
#: Title       : mactools.sh
#: Date        : 2026-05-15
#: Updated     :
#: Author      : Thierry Gautier <thierry.gautier@univ-grenoble-alpes.fr>
#: Version     : 0.1
#: Description : Collection of personal cli macOS tools.
#: Usage       : ./mactools [options]
#: Options     :
set -euo pipefail

# --- Configuration ---

# An array of application names (e.g., "Safari.app") to exclude from processing.
EXCLUDED_APPS=(
    "Safari.app"
)

# --- ANSI Color Codes for Better Output ---
VERSION="0.1"
NC='\033[0m' # No Color
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
LINE="--------------------------------------------------"
#HIERARCHY_DIR="${HOME}/Documents/BIO713/TP/files/pombe"
#TARGET_DIR="${HOME}/Documents/BIO713/TP"

# --- Functions ---

# Helper function to check if an item is in an array
# Usage: contains_element "item" "${array[@]}"
contains_element() {
    local e match="$1"
    shift
    for e; do [[ "$e" == "$match" ]] && return 0; done
    return 1
}

# Check the OS and display information
function detect_os() {
    OSV="$(uname -o)"
    OSR="$(uname -r)"
    proc="$(uname -m)"
    case "$proc" in
        arm64*) MAC="silicon"; echo -e "${YELLOW}💻 Script launched on Apple Silicon Mac${NC}";;
        x86_64*) MAC="intel"; echo -e "${YELLOW}💻 Script launched on Intel Mac${NC}";;
        *) echo -e "${RED}Error: This script is designed to run only on Apple Silicon (arm64) or Intel (x86_64) Macs.${NC}";
           echo -e "${RED}==> Unsupported OS $OS{$NC}"; exit 1 ;;
    esac
    echo ${LINE}
    echo -e "             Processor: ${proc}"
    echo -e "             OS version: ${OSV}, ${OSR}\n"
}

# Scans the Application folder looking for Universal apps
function scanning_app(){
echo -e "🔎 ${YELLOW}Scanning /Applications for Universal Binaries...${NC}"
echo ${LINE}

UNIVERSAL_BINARIES=()
UNIVERSAL_APP_NAMES=()

# 2. Find Universal Apps: Loop through all .app bundles.
for APP_PATH in "/Applications"/*.app; do
    APP_FILENAME=$(basename "$APP_PATH")

    # Skip if the app is in our exclusion list.
    if contains_element "$APP_FILENAME" "${EXCLUDED_APPS[@]}"; then
        echo -e "➡️  Skipping excluded app: \"${APP_FILENAME%.app}\""
        continue
    fi

    # Define paths for the Info.plist and the main executable.
    PLIST_PATH="${APP_PATH}/Contents/Info.plist"
    [ ! -f "$PLIST_PATH" ] && continue

    EXECUTABLE_NAME=$(defaults read "${PLIST_PATH}" CFBundleExecutable 2>/dev/null)
    [ -z "$EXECUTABLE_NAME" ] && continue

    BINARY_PATH="${APP_PATH}/Contents/MacOS/${EXECUTABLE_NAME}"

    # Check if the binary exists and is a "fat" file with both architectures.
    if [ -f "$BINARY_PATH" ]; then
        ARCH_INFO=$(lipo -info "$BINARY_PATH" 2>/dev/null)

        if echo "$ARCH_INFO" | grep -q "x86_64" && echo "$ARCH_INFO" | grep -q "arm64"; then
            APP_NAME=$(basename "$APP_PATH" .app)
            echo -e "✅ Found: \"${BOLD}${APP_NAME}${NC}\""

            UNIVERSAL_BINARIES+=("$BINARY_PATH")
            UNIVERSAL_APP_NAMES+=("$APP_NAME")
        fi
    fi
done

echo ${LINE}
}

function thinning_apps(){
    if [ ${#UNIVERSAL_BINARIES[@]} -eq 0 ]; then
        echo -e "👍 ${GREEN}No Universal applications requiring changes were found. All done!${NC}"
        exit 0
    fi

    echo -e "The following ${BOLD}${YELLOW}${#UNIVERSAL_BINARIES[@]}${NC} Universal application(s) can be thinned:"
    printf " - %s\n" "${UNIVERSAL_APP_NAMES[@]}"
    echo ""
    echo -e "${YELLOW}${BOLD}Important:${NC} This operation modifies application files and requires administrator privileges."
    echo -e "On its first run, macOS may ask you to grant ${BOLD}Terminal${NC} permission for ${BOLD}'App Management'${NC} in System Settings."
    echo ""

    read -p "Do you want to strip the unnecessary binary from ALL of these apps? (y/n): " CONFIRMATION
    LOWER_CONFIRMATION=$(echo "$CONFIRMATION" | tr '[:upper:]' '[:lower:]')

    if [[ "$LOWER_CONFIRMATION" == "y" || "$LOWER_CONFIRMATION" == "yes" ]]; then
        echo ""
        echo -e "🚀 ${BLUE}Stripping binaries... You will be prompted for your password.${NC}"

        PROCESSED_COUNT=0
        if [[ "$MAC" == "silicon" ]]; then
            ARCH="x86_64"
        else
            ARCH="arm64"
        fi
        for BINARY_PATH in "${UNIVERSAL_BINARIES[@]}"; do
            # Use sudo with the lipo command to request privileges only when needed.
            if sudo lipo -remove "$ARCH" -output "$BINARY_PATH" "$BINARY_PATH"; then
                ((PROCESSED_COUNT++))
            else
                APP_NAME_FROM_PATH=$(basename "$(dirname "$(dirname "$BINARY_PATH")")" .app)
                echo -e "${RED}Failed to strip binary for \"${APP_NAME_FROM_PATH}\".${NC}"
            fi
        done

        echo ${LINE}
        echo -e "✨ ${GREEN}All done. Processed ${PROCESSED_COUNT} application(s).${NC}"
    else
        echo -e "👍 ${YELLOW}Operation cancelled. No changes were made.${NC}"
    fi

    echo ${LINE}
}

function thinning_one_app(){
    read -p "Do you want to strip the unnecessary binary from A SINGLE app? (y/n): " CONFIRMATION
    LOWER_CONFIRMATION=$(echo "$CONFIRMATION" | tr '[:upper:]' '[:lower:]')

    if [[ "$LOWER_CONFIRMATION" == "y" || "$LOWER_CONFIRMATION" == "yes" ]]; then
        echo ""
        echo -e "🚀 ${BLUE}Stripping binary... You will be prompted for your password.${NC}"
        if [[ "$MAC" == "silicon" ]]; then
            ARCH="x86_64"
        else
            ARCH="arm64"
        fi
        for BINARY_PATH in "${UNIVERSAL_BINARIES[@]}"; do
            # Use sudo with the lipo command to request privileges only when needed.
            if sudo lipo -remove "$ARCH" -output "$BINARY_PATH" "$BINARY_PATH"; then
                ((PROCESSED_COUNT++))
            else
                APP_NAME_FROM_PATH=$(basename "$(dirname "$(dirname "$BINARY_PATH")")" .app)
                echo -e "${RED}Failed to strip binary for \"${APP_NAME_FROM_PATH}\".${NC}"
            fi
        done

        echo ${LINE}
        echo -e "✨ ${GREEN}All done. Processed ${PROCESSED_COUNT} application(s).${NC}"
    else
        echo -e "👍 ${YELLOW}Operation cancelled. No changes were made.${NC}"
    fi

    echo ${LINE}
}

# --- Main Logic ---

echo -e "\n${BLUE}${BOLD}mactools: MacOS App Thinner${NC}"
echo ${LINE}
echo "This script will scan for Universal apps and offer to remove the Intel (x86_64) or Arm64 portion"
echo "of code in accordance with architecture."
echo ""

# 1. Architecture Check: Ensure the script is running on a Mac.
#Detect OS for correct architecture
detect_os
# 2. Scan the Application folder
scanning_app
# 3. Confirmation and Processing for all apps
thinning_apps
# 4. Confirmation and Processing for a single app
thinning_one_app
exit 0
