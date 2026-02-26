#!/bin/bash
######################################################################################
## PROGRAM   : thermal-monitor.sh
## PROGRAMER : Brett Collingwood
## MUSE      : Kit
## VERSION   : 1.2.0
## DATE      : 2026-02-23
## PURPOSE   : Thermal monitoring (idle/load)
## #---------------------------------------------------------------------------------#
## THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
## INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
## PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
## HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
## OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
## SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
######################################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# Default configuration
DURATION=60
INTERVAL=5
LOAD_TEST=false
LOAD_WORKERS=$(nproc)

# Check for dialog
USE_DIALOG=false
if command -v dialog &> /dev/null; then
    USE_DIALOG=true
fi

configure_test() {
    if [ "$USE_DIALOG" = true ]; then
        configure_test_dialog
    else
        configure_test_text
    fi
}

configure_test_dialog() {
    while true; do
        # Main Menu
        cmd=(dialog --clear --backtitle "Linux Test Suite - Thermal Monitor" \
            --title "Thermal Monitor Configuration" \
            --menu "Current Settings:\n\n1) Duration:      ${DURATION}s\n2) Interval:      ${INTERVAL}s\n3) Apply Load:    $LOAD_TEST\n4) Load Workers:  $LOAD_WORKERS\n\nNotes:\n- Monitors CPU temperature over time\n- 'Apply Load' runs stress-ng during monitoring\n\nSelect option to change or run:" 22 65 6)
        
        options=(
            1 "Duration (seconds)"
            2 "Sample Interval (seconds)"
            3 "Toggle Load Test (stress-ng)"
            4 "Load Workers"
            R "Run test with current settings"
            Q "Return to main menu"
        )
        
        choice=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
        
        case $choice in
            1)
                val=$(dialog --clear --backtitle "Linux Test Suite - Thermal Monitor" \
                    --title "Duration" \
                    --inputbox "Enter duration in seconds:" 8 40 "$DURATION" \
                    2>&1 >/dev/tty)
                [[ "$val" =~ ^[0-9]+$ ]] && DURATION=$val
                ;;
            2)
                val=$(dialog --clear --backtitle "Linux Test Suite - Thermal Monitor" \
                    --title "Sample Interval" \
                    --inputbox "Enter sample interval in seconds:" 8 40 "$INTERVAL" \
                    2>&1 >/dev/tty)
                [[ "$val" =~ ^[0-9]+$ ]] && INTERVAL=$val
                ;;
            3)
                if [ "$LOAD_TEST" = true ]; then
                    LOAD_TEST=false
                else
                    LOAD_TEST=true
                fi
                ;;
            4)
                val=$(dialog --clear --backtitle "Linux Test Suite - Thermal Monitor" \
                    --title "Load Workers" \
                    --inputbox "Enter number of load workers (1-$(nproc)):" 8 40 "$LOAD_WORKERS" \
                    2>&1 >/dev/tty)
                [[ "$val" =~ ^[0-9]+$ ]] && LOAD_WORKERS=$val
                ;;
            R)
                clear
                run_test
                echo ""
                read -p "Press Enter to continue..."
                ;;
            Q|"")
                return 0
                ;;
        esac
    done
}

configure_test_text() {
    while true; do
        clear
        echo "=============================================="
        echo "  Thermal Monitor Configuration"
        echo "=============================================="
        echo ""
        echo "Current Settings:"
        echo "  1) Duration:      ${DURATION}s"
        echo "  2) Interval:      ${INTERVAL}s"
        echo "  3) Apply Load:    $LOAD_TEST"
        echo "  4) Load Workers:  $LOAD_WORKERS"
        echo ""
        echo "Notes:"
        echo "  - Monitors CPU temperature over time"
        echo "  - 'Apply Load' runs stress-ng during monitoring"
        echo ""
        echo "  r) Run test with current settings"
        echo "  q) Return to main menu"
        echo ""
        echo "              *** Use Not Intended For Benchmarking Purposes ***"
        echo ""
        read -p "Select option: " choice
        
        case $choice in
            1)
                read -p "Enter duration in seconds: " val
                [[ "$val" =~ ^[0-9]+$ ]] && DURATION=$val
                ;;
            2)
                read -p "Enter sample interval in seconds: " val
                [[ "$val" =~ ^[0-9]+$ ]] && INTERVAL=$val
                ;;
            3)
                if [ "$LOAD_TEST" = true ]; then
                    LOAD_TEST=false
                else
                    LOAD_TEST=true
                fi
                ;;
            4)
                read -p "Enter load workers (1-$(nproc)): " val
                [[ "$val" =~ ^[0-9]+$ ]] && LOAD_WORKERS=$val
                ;;
            r|R)
                run_test
                read -p "Press Enter to continue..."
                ;;
            q|Q)
                return 0
                ;;
        esac
    done
}

# Get CPU temperature from various sources
get_cpu_temp() {
    local temp=""
    
    # Try hwmon thermal zones (most common on ARM)
    for zone in /sys/class/thermal/thermal_zone*/temp; do
        if [ -f "$zone" ]; then
            local zone_temp=$(cat "$zone" 2>/dev/null)
            if [ -n "$zone_temp" ]; then
                # Convert from millidegrees to degrees
                temp=$(echo "scale=1; $zone_temp / 1000" | bc 2>/dev/null || echo "$((zone_temp / 1000))")
                break
            fi
        fi
    done
    
    # Try lm-sensors if available and no temp found
    if [ -z "$temp" ] && check_command "sensors"; then
        temp=$(sensors 2>/dev/null | grep -E "Core 0|CPU|Tctl|temp1" | head -1 | grep -oE "[0-9]+\.[0-9]+" | head -1)
    fi
    
    # Try vcgencmd for Raspberry Pi
    if [ -z "$temp" ] && check_command "vcgencmd"; then
        temp=$(vcgencmd measure_temp 2>/dev/null | grep -oE "[0-9]+\.[0-9]+")
    fi
    
    echo "${temp:-N/A}"
}

# Get all thermal zone info
get_all_thermal_info() {
    echo "Thermal Zones:"
    
    for zone_path in /sys/class/thermal/thermal_zone*; do
        if [ -d "$zone_path" ]; then
            local zone_name=$(basename "$zone_path")
            local zone_type=$(cat "$zone_path/type" 2>/dev/null || echo "unknown")
            local zone_temp=$(cat "$zone_path/temp" 2>/dev/null)
            
            if [ -n "$zone_temp" ]; then
                local temp_c=$(echo "scale=1; $zone_temp / 1000" | bc 2>/dev/null || echo "$((zone_temp / 1000))")
                echo "  $zone_name ($zone_type): ${temp_c}°C"
            fi
        fi
    done
    
    # Also show lm-sensors output if available
    if check_command "sensors"; then
        echo ""
        echo "lm-sensors output:"
        sensors 2>/dev/null | head -20
    fi
}

# Get CPU frequency
get_cpu_freq() {
    local freq=""
    
    # Try cpufreq
    if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq ]; then
        local freq_khz=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null)
        if [ -n "$freq_khz" ]; then
            freq=$(echo "scale=0; $freq_khz / 1000" | bc 2>/dev/null || echo "$((freq_khz / 1000))")
            freq="${freq} MHz"
        fi
    fi
    
    # Try lscpu
    if [ -z "$freq" ]; then
        freq=$(lscpu 2>/dev/null | grep "CPU MHz" | awk '{print $3}' | head -1)
        [ -n "$freq" ] && freq="${freq} MHz"
    fi
    
    echo "${freq:-N/A}"
}

# Get CPU load average
get_cpu_load() {
    local load=$(cat /proc/loadavg 2>/dev/null | awk '{print $1}')
    echo "${load:-N/A}"
}

# Main monitoring loop logic (wrapped for background execution)
perform_monitoring() {
    local result_file="$1"
    
    local stress_pid=""
    
    # Start stress-ng if load test enabled
    if [ "$LOAD_TEST" = true ]; then
        if check_command "stress-ng"; then
            echo "Starting CPU Load (stress-ng)"
            echo "Starting stress-ng with $LOAD_WORKERS workers..."
            stress-ng --cpu "$LOAD_WORKERS" --timeout "${DURATION}s" &>/dev/null &
            stress_pid=$!
            echo "Stress PID: $stress_pid"
            echo "" >> "$result_file"
            echo "Load test started: stress-ng --cpu $LOAD_WORKERS (PID: $stress_pid)" >> "$result_file"
        else
            echo "stress-ng not available - running without load"
            echo "WARNING: stress-ng not available - monitoring idle temps" >> "$result_file"
        fi
    fi
    
    echo "Temperature Monitoring"
    echo "Monitoring for ${DURATION}s at ${INTERVAL}s intervals..."
    echo ""
    
    {
        echo ""
        echo "Temperature Log:"
        printf "%-12s %-12s %-12s %-12s\n" "Time" "Temp (°C)" "CPU Freq" "Load"
        printf "%-12s %-12s %-12s %-12s\n" "----" "--------" "--------" "----"
    } >> "$result_file"
    
    local elapsed=0
    local temps=()
    local start_time=$(date +%s)
    
    while [ $elapsed -lt $DURATION ]; do
        local current_time=$(date +%H:%M:%S)
        local temp=$(get_cpu_temp)
        local freq=$(get_cpu_freq)
        local load=$(get_cpu_load)
        
        printf "%-12s %-12s %-12s %-12s\n" "$current_time" "$temp" "$freq" "$load" >> "$result_file"
        
        # Store temp for stats (if numeric)
        if [[ "$temp" =~ ^[0-9]+\.?[0-9]*$ ]]; then
            temps+=("$temp")
        fi
        
        sleep "$INTERVAL"
        elapsed=$(($(date +%s) - start_time))
    done
    
    # Stop stress-ng if running
    if [ -n "$stress_pid" ]; then
        echo ""
        echo "Stopping stress-ng..."
        kill "$stress_pid" 2>/dev/null
        wait "$stress_pid" 2>/dev/null
    fi
    
    # Calculate statistics
    echo "" >> "$result_file"
    echo "Statistics:" >> "$result_file"
    
    if [ ${#temps[@]} -gt 0 ]; then
        local min_temp=$(printf '%s\n' "${temps[@]}" | sort -n | head -1)
        local max_temp=$(printf '%s\n' "${temps[@]}" | sort -n | tail -1)
        local sum=0
        for t in "${temps[@]}"; do
            sum=$(echo "scale=1; $sum + $t" | bc 2>/dev/null || echo "$sum")
        done
        local avg_temp=$(echo "scale=1; $sum / ${#temps[@]}" | bc 2>/dev/null || echo "N/A")
        
        {
            echo "  Min Temp: ${min_temp}°C"
            echo "  Max Temp: ${max_temp}°C"
            echo "  Avg Temp: ${avg_temp}°C"
            echo "  Samples:  ${#temps[@]}"
        } >> "$result_file"
    else
        echo "  No temperature data collected" >> "$result_file"
    fi
}

# Export the function so it can be used by run_with_progress (via eval in same shell context)
# Actually, since common.sh is sourced, functions are available.
# But run_with_progress does `eval "$cmd"`. If cmd calls a function, it works.

run_test() {
    print_header "Thermal Monitor"
    
    local result_file=$(start_test "Thermal Monitor")
    print_success "Results will be saved to: $result_file"
    
    {
        echo "Configuration:"
        echo "  Duration:     ${DURATION}s"
        echo "  Interval:     ${INTERVAL}s"
        echo "  Apply Load:   $LOAD_TEST"
        echo "  Load Workers: $LOAD_WORKERS"
        echo ""
        get_all_thermal_info
        echo ""
    } >> "$result_file"
    
    # Run the monitoring logic with progress
    # We pass the function call as the command string
    # Variables DURATION, INTERVAL, LOAD_TEST, LOAD_WORKERS are global/visible
    
    run_with_progress "perform_monitoring \"$result_file\"" "$result_file"
    
    end_test "$result_file" 0
    
    print_success "Thermal monitoring completed"
    echo ""
    echo "Results saved to: $result_file"
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        --run) run_test ;;
        --configure|"") configure_test ;;
        *) echo "Usage: $0 [--run|--configure]"; exit 1 ;;
    esac
fi
