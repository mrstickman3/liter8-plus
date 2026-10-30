#!/bin/zsh

# Liter8 Setup and Workflow Script
# This script automates the custom iOS 27 patching and booting process.

set -e

# --- Configuration ---
# Set your IPSW path here or the script will ask for it.
IPSW_PATH=""
# Set your work directory here or it defaults to .liter8
WORK_DIR="${WORK_DIR:-$PWD/.liter8}"
LITER8_BIN=".build/release/liter8"
STATE_FILE="$WORK_DIR/.liter8_state"

# ANSI Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper for pwn DFU confirmations
confirm_pwn_dfu() {
    echo ""
    echo "${RED}--------------------------------------------------------------------------------${NC}"
    echo "${RED}ACTION REQUIRED: Put the device into pwn DFU mode now.${NC}"
    echo "${RED}--------------------------------------------------------------------------------${NC}"
    while true; do
        read -k 1 -r "reply"
        echo ""
        case $reply in
            [Yy]) break ;;
            [Nn]) echo "Exiting script."; exit 1 ;;
            *) echo "Please enter 'y' to continue or 'n' to abort." ;;
        esac
    done
}

# State Management
save_state() {
    local step=$1
    mkdir -p "$WORK_DIR"
    echo "last_completed_step=$step" > "$STATE_FILE"
    echo "timestamp=$(date +%s)" >> "$STATE_FILE"
    if [[ -n "$IPSW_PATH" ]]; then
        echo "ipsw_path=$IPSW_PATH" >> "$STATE_FILE"
    fi
}

get_state() {
    if [[ -f "$STATE_FILE" ]]; then
        # Simple key=value parsing
        grep "last_completed_step=" "$STATE_FILE" | cut -d'=' -f2
    else
        echo "0"
    fi
}

# Check for binary
if [[ ! -f "$LITER8_BIN" ]]; then
    echo "${RED}Error: $LITER8_BIN not found.${NC}"
    echo "Please run 'make release' first to build the CLI."
    exit 1
fi

export WORK_DIR="$WORK_DIR"
echo "${BLUE}Using work directory: $WORK_DIR${NC}"

# Load state
CURRENT_STEP=$(get_state)
echo "Resuming from step: $((CURRENT_STEP + 1))"

# 1. Prepare the IPSW
if [[ $CURRENT_STEP -lt 1 ]]; then
    if [[ -z "$IPSW_PATH" ]]; then
        # Try to load from state first
        if [[ -f "$STATE_FILE" ]]; then
            IPSW_PATH=$(grep "ipsw_path=" "$STATE_FILE" | cut -d'=' -f2)
        fi

        if [[ -z "$IPSW_PATH" ]]; then
            echo -n "Enter path to firmware IPSW: "
            read IPSW_PATH
        fi
    fi

    if [[ ! -f "$IPSW_PATH" ]]; then
        echo "${RED}Error: IPSW file not found at $IPSW_PATH${NC}"
        exit 1
    fi

    echo "${YELLOW}Step 1: Preparing IPSW...${NC}"
    "$LITER8_BIN" fw prepare --file "$IPSW_PATH"
    save_state 1
fi

# 2. Build the CFW
if [[ $CURRENT_STEP -lt 2 ]]; then
    echo "${YELLOW}Step 2: Building CFW...${NC}"
    "$LITER8_BIN" fw make-cfw
    save_state 2
fi

# 3. Restore it
if [[ $CURRENT_STEP -lt 3 ]]; then
    confirm_pwn_dfu
    echo "${YELLOW}Step 3: Restoring CFW (This wipes the phone!)...${NC}"
    "$LITER8_BIN" fw restore-cfw
    save_state 3
fi

# 4. Boot the SSH ramdisk
if [[ $CURRENT_STEP -lt 4 ]]; then
    confirm_pwn_dfu
    echo "${YELLOW}Step 4a: Getting ramdisk...${NC}"
    "$LITER8_BIN" fw get-rd
    echo "${YELLOW}Step 4b: Booting ramdisk...${NC}"
    "$LITER8_BIN" fw boot-rd
    save_state 4
fi

# 5. Provision
if [[ $CURRENT_STEP -lt 5 ]]; then
    echo "${YELLOW}Step 5: Provisioning device...${NC}"
    "$LITER8_BIN" fw bootstrap --check
    "$LITER8_BIN" fw bootstrap
    "$LITER8_BIN" fw prepare-rootfs
    "$LITER8_BIN" fw provision --check
    "$LITER8_BIN" fw provision
    "$LITER8_BIN" fw unmount-rootfs
    save_state 5
fi

# 6. Boot iOS
if [[ $CURRENT_STEP -lt 6 ]]; then
    confirm_pwn_dfu
    echo "${YELLOW}Step 6a: Getting boot artifacts...${NC}"
    "$LITER8_BIN" fw get-boot
    echo "${YELLOW}Step 6b: Booting iOS...${NC}"
    "$LITER8_BIN" fw boot
    save_state 6
fi

echo ""
echo "${GREEN}Device should now be booting iOS. Please wait for it to reach the home screen.${NC}"
echo "Once you can SSH into the device, you can run the final step manually:"
echo "  $LITER8_BIN fw finalize"
echo ""

# 7. Finish the bootstrap
if [[ $CURRENT_STEP -lt 7 ]]; then
    echo -n "Do you want to run 'fw finalize' now? (y/n): "
    read -k 1 -r "final_reply"
    echo ""
    if [[ "$final_reply" =~ ^[Yy]$ ]]; then
        echo "${YELLOW}Step 7: Finalizing bootstrap...${NC}"
        "$LITER8_BIN" fw finalize --check
        "$LITER8_BIN" fw finalize
        "$LITER8_BIN" fw finalize --check
        save_state 7
        echo "${GREEN}Bootstrap finalized successfully.${NC}"
    else
        echo "Skipping finalize. Remember to run it once the device is booted and SSH is available."
    fi
fi

echo "${GREEN}Workflow complete.${NC}"
