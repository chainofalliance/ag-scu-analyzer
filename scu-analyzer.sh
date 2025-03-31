#!/bin/bash

# Function to identify CPU cores based on OS
get_cpu_cores() {
    if [[ "$(uname)" == "Darwin" ]]; then
        # macOS
        sysctl -n hw.ncpu
    elif [[ "$(uname)" == "Linux" ]]; then
        # Linux
        nproc
    else
        # Windows or other systems with grep available
        grep -c ^processor /proc/cpuinfo 2>/dev/null || echo "1"
    fi
}

# Function to identify available RAM in MB based on OS
get_ram_mb() {
    if [[ "$(uname)" == "Darwin" ]]; then
        # macOS
        echo $(($(sysctl -n hw.memsize) / 1024 / 1024))
    elif [[ "$(uname)" == "Linux" ]]; then
        # Linux
        free -m | grep Mem | awk '{print $2}'
    else
        # Windows or systems where we can't easily get memory
        echo "1024" # Default to 1GB if we can't determine
    fi
}

# Function to run speedtest and get bandwidth in Mbps
get_bandwidth_mbps() {
    local speed=""
    
    # Try to use system packages first (output redirected to prevent interference)
    if command -v apt-get &> /dev/null; then
        # Check if speedtest is already installed via apt
        if ! command -v speedtest-cli &> /dev/null; then
            echo "Attempting to install speedtest-cli via apt..." >&2
            sudo apt-get update >&2 && sudo apt-get install -y speedtest-cli >&2
        fi
    elif command -v yum &> /dev/null; then
        if ! command -v speedtest-cli &> /dev/null; then
            echo "Attempting to install speedtest-cli via yum..." >&2
            sudo yum install -y speedtest-cli >&2
        fi
    elif command -v brew &> /dev/null; then
        if ! command -v speedtest-cli &> /dev/null; then
            echo "Attempting to install speedtest-cli via brew..." >&2
            brew install speedtest-cli >&2
        fi
    fi
    
    # If speedtest-cli is available now, use it
    if command -v speedtest-cli &> /dev/null; then
        echo "Running speedtest (this may take a minute)..." >&2
        speed=$(speedtest-cli --simple | grep "Download" | awk '{print $2}')
    fi
    
    # If we got a valid speed, return it; otherwise use default
    if [[ -n "$speed" ]]; then
        echo "$speed"
    else
        echo "Could not determine bandwidth. Using default value." >&2
        echo "20"
    fi
}

# Calculate available SCUs
calculate_scu() {
    local cpu_cores=$1
    local ram_mb=$2
    local bandwidth_mbps=$3
    
    # Convert bandwidth from Mbps to kbps (1 Mbps = 1000 kbps)
    local bandwidth_kbps=$(echo "$bandwidth_mbps * 1000" | bc)
    
    # Calculate SCUs based on the formula
    local cpu_scu=$(echo "$cpu_cores * 10" | bc)
    local ram_scu=$(echo "$ram_mb / 100" | bc)
    local bandwidth_scu=$(echo "$bandwidth_kbps / 200" | bc)
    
    echo "CPU cores: $cpu_cores (SCU capacity: $cpu_scu)"
    echo "RAM: $ram_mb MB (SCU capacity: $ram_scu)"
    echo "Bandwidth: $bandwidth_mbps Mbps / $bandwidth_kbps Kbps (SCU capacity: $bandwidth_scu)"
    
    # Find the minimum value
    local min_scu=$cpu_scu
    if (( $(echo "$ram_scu < $min_scu" | bc -l) )); then
        min_scu=$ram_scu
    fi
    if (( $(echo "$bandwidth_scu < $min_scu" | bc -l) )); then
        min_scu=$bandwidth_scu
    fi
    
    echo "----------------------------------------"
    echo "SCUs available on this system: $min_scu"
    echo "----------------------------------------"
}

# Main script execution
echo "Identifying system resources for SCU calculation..."

CPU_CORES=$(get_cpu_cores)
RAM_MB=$(get_ram_mb)
BANDWIDTH_MBPS=$(get_bandwidth_mbps)

# Handle potential non-numeric values 
if ! [[ "$BANDWIDTH_MBPS" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    echo "Bandwidth test failed, using default of 20 Mbps"
    BANDWIDTH_MBPS=20
fi

echo "----------------------------------------"
SCU=$(calculate_scu $CPU_CORES $RAM_MB $BANDWIDTH_MBPS)
echo "$SCU"
