#!/bin/bash
######################################################################################
## PROGRAM   : network-test.sh
## PROGRAMER : Brett Collingwood
## MUSE      : Kit
## VERSION   : 1.2.0
## DATE      : 2026-02-23
## PURPOSE   : Network performance tests (iPerf, Speedtest, Ping)
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
TEST_TYPE="all"
IPERF_SERVER=""
IPERF_PORT=5201
IPERF_DURATION=10
IPERF_PARALLEL=4
PING_TARGET="8.8.8.8"
PING_COUNT=20

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
        cmd=(dialog --clear --backtitle "Linux Test Suite - Network Test" \
            --title "Network Test Configuration" \
            --menu "Current Settings:\n\n1) Test Type:      $TEST_TYPE\n2) Ping Target:    $PING_TARGET\n3) Ping Count:     $PING_COUNT\n4) iPerf Server:   ${IPERF_SERVER:-<not set>}\n5) iPerf Port:     $IPERF_PORT\n6) iPerf Duration: ${IPERF_DURATION}s\n7) iPerf Parallel: $IPERF_PARALLEL streams\n\nSelect option to change or run:" 22 65 9)
        
        options=(
            1 "Test Type (all, speedtest, iperf, latency)"
            2 "Ping Target (IP/Hostname)"
            3 "Ping Count"
            4 "iPerf Server (IP/Hostname)"
            5 "iPerf Port"
            6 "iPerf Duration (seconds)"
            7 "iPerf Parallel Streams"
            R "Run test with current settings"
            Q "Return to main menu"
        )
        
        choice=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
        
        case $choice in
            1)
                tt=$(dialog --clear --backtitle "Linux Test Suite - Network Test" \
                    --title "Select Test Type" \
                    --menu "Choose network test type:" 15 50 4 \
                    all "Run all available tests" \
                    speedtest "Internet speed test" \
                    iperf "iPerf3 bandwidth (needs server)" \
                    latency "Ping latency/jitter" \
                    2>&1 >/dev/tty)
                [[ -n "$tt" ]] && TEST_TYPE=$tt
                ;;
            2)
                val=$(dialog --clear --backtitle "Linux Test Suite - Network Test" \
                    --title "Ping Target" \
                    --inputbox "Enter ping target (IP or hostname):" 8 40 "$PING_TARGET" \
                    2>&1 >/dev/tty)
                [[ -n "$val" ]] && PING_TARGET=$val
                ;;
            3)
                val=$(dialog --clear --backtitle "Linux Test Suite - Network Test" \
                    --title "Ping Count" \
                    --inputbox "Enter ping count:" 8 40 "$PING_COUNT" \
                    2>&1 >/dev/tty)
                [[ "$val" =~ ^[0-9]+$ ]] && PING_COUNT=$val
                ;;
            4)
                val=$(dialog --clear --backtitle "Linux Test Suite - Network Test" \
                    --title "iPerf Server" \
                    --inputbox "Enter iPerf server (IP or hostname):" 8 40 "$IPERF_SERVER" \
                    2>&1 >/dev/tty)
                IPERF_SERVER=$val
                ;;
            5)
                val=$(dialog --clear --backtitle "Linux Test Suite - Network Test" \
                    --title "iPerf Port" \
                    --inputbox "Enter iPerf port:" 8 40 "$IPERF_PORT" \
                    2>&1 >/dev/tty)
                [[ "$val" =~ ^[0-9]+$ ]] && IPERF_PORT=$val
                ;;
            6)
                val=$(dialog --clear --backtitle "Linux Test Suite - Network Test" \
                    --title "iPerf Duration" \
                    --inputbox "Enter iPerf duration (seconds):" 8 40 "$IPERF_DURATION" \
                    2>&1 >/dev/tty)
                [[ "$val" =~ ^[0-9]+$ ]] && IPERF_DURATION=$val
                ;;
            7)
                val=$(dialog --clear --backtitle "Linux Test Suite - Network Test" \
                    --title "iPerf Parallel Streams" \
                    --inputbox "Enter number of parallel streams:" 8 40 "$IPERF_PARALLEL" \
                    2>&1 >/dev/tty)
                [[ "$val" =~ ^[0-9]+$ ]] && IPERF_PARALLEL=$val
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
        echo "  Network Test Configuration"
        echo "=============================================="
        echo ""
        echo "Current Settings:"
        echo "  1) Test Type:      $TEST_TYPE"
        echo "  2) Ping Target:    $PING_TARGET"
        echo "  3) Ping Count:     $PING_COUNT"
        echo "  4) iPerf Server:   ${IPERF_SERVER:-<not set>}"
        echo "  5) iPerf Port:     $IPERF_PORT"
        echo "  6) iPerf Duration: ${IPERF_DURATION}s"
        echo "  7) iPerf Parallel: $IPERF_PARALLEL streams"
        echo ""
        echo "Test types:"
        echo "     all       - Run all available tests"
        echo "     speedtest - Internet speed test (speedtest-cli)"
        echo "     iperf     - iPerf3 bandwidth test (needs server)"
        echo "     latency   - Ping latency/jitter test"
        echo ""
        echo "  r) Run test with current settings"
        echo "  q) Return to main menu"
        echo ""
        echo "              *** Use Not Intended For Benchmarking Purposes ***"
        echo ""
        read -p "Select option: " choice
        
        case $choice in
            1)
                read -p "Enter test type (all/speedtest/iperf/latency): " val
                [[ -n "$val" ]] && TEST_TYPE=$val
                ;;
            2)
                read -p "Enter ping target (IP or hostname): " val
                [[ -n "$val" ]] && PING_TARGET=$val
                ;;
            3)
                read -p "Enter ping count: " val
                [[ "$val" =~ ^[0-9]+$ ]] && PING_COUNT=$val
                ;;
            4)
                read -p "Enter iPerf server (IP or hostname): " val
                IPERF_SERVER=$val
                ;;
            5)
                read -p "Enter iPerf port: " val
                [[ "$val" =~ ^[0-9]+$ ]] && IPERF_PORT=$val
                ;;
            6)
                read -p "Enter iPerf duration (seconds): " val
                [[ "$val" =~ ^[0-9]+$ ]] && IPERF_DURATION=$val
                ;;
            7)
                read -p "Enter iPerf parallel streams: " val
                [[ "$val" =~ ^[0-9]+$ ]] && IPERF_PARALLEL=$val
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

# Run speedtest-cli
run_speedtest() {
    local result_file="$1"
    
    print_header "Speedtest (Internet Bandwidth)"
    
    # Check for speedtest-cli (can be 'speedtest-cli' or 'speedtest')
    local speedtest_cmd=""
    if check_command "speedtest-cli"; then
        speedtest_cmd="speedtest-cli"
    elif check_command "speedtest"; then
        speedtest_cmd="speedtest"
    else
        print_warning "speedtest-cli not found. Attempting to install..."
        if ! install_package "speedtest-cli"; then
            echo "SKIPPED: speedtest-cli not available" >> "$result_file"
            return 1
        fi
        speedtest_cmd="speedtest-cli"
    fi
    
    {
        echo "--- Speedtest (Internet Bandwidth) ---"
        echo "Tool: $speedtest_cmd"
        echo ""
    } >> "$result_file"
    
    echo "Running internet speed test..."
    echo "(This may take a minute to find the best server)"
    
    local cmd="$speedtest_cmd --simple"
    run_with_progress "$cmd" "$result_file"
    local exit_code=$?
    
    # Also run with more details
    echo "" >> "$result_file"
    echo "Detailed results:" >> "$result_file"
    
    local cmd_detail="$speedtest_cmd"
    run_with_progress "$cmd_detail" "$result_file"
    
    echo "" >> "$result_file"
    return $exit_code
}

# Run iperf3 test
run_iperf() {
    local result_file="$1"
    
    print_header "iPerf3 (LAN Bandwidth)"
    
    if ! require_dependency "iperf3"; then
        echo "SKIPPED: iperf3 not available" >> "$result_file"
        return 1
    fi
    
    if [ -z "$IPERF_SERVER" ]; then
        print_warning "iPerf server not configured. Skipping iPerf test."
        print_warning "Set an iPerf server address in the configuration menu."
        echo "SKIPPED: No iPerf server configured" >> "$result_file"
        return 1
    fi
    
    {
        echo "--- iPerf3 (LAN Bandwidth) ---"
        echo "Server: $IPERF_SERVER:$IPERF_PORT"
        echo "Duration: ${IPERF_DURATION}s"
        echo "Parallel: $IPERF_PARALLEL streams"
        echo ""
    } >> "$result_file"
    
    # Test TCP upload
    echo "Testing TCP upload to $IPERF_SERVER..."
    {
        echo "=== TCP Upload ==="
    } >> "$result_file"
    
    local cmd="iperf3 -c $IPERF_SERVER -p $IPERF_PORT -t $IPERF_DURATION -P $IPERF_PARALLEL"
    run_with_progress "$cmd" "$result_file"
    local upload_code=$?
    
    echo "" >> "$result_file"
    
    # Test TCP download
    echo "Testing TCP download from $IPERF_SERVER..."
    {
        echo "=== TCP Download ==="
    } >> "$result_file"
    
    local cmd="iperf3 -c $IPERF_SERVER -p $IPERF_PORT -t $IPERF_DURATION -P $IPERF_PARALLEL -R"
    run_with_progress "$cmd" "$result_file"
    local download_code=$?
    
    echo "" >> "$result_file"
    
    # Test UDP (for jitter/packet loss)
    echo "Testing UDP to $IPERF_SERVER..."
    {
        echo "=== UDP Test ==="
    } >> "$result_file"
    
    local cmd="iperf3 -c $IPERF_SERVER -p $IPERF_PORT -t $IPERF_DURATION -u -b 100M"
    run_with_progress "$cmd" "$result_file"
    
    echo "" >> "$result_file"
    
    [ $upload_code -eq 0 ] && [ $download_code -eq 0 ]
    return $?
}

# Run ping latency test
run_latency() {
    local result_file="$1"
    
    print_header "Ping Latency Test"
    
    if ! check_command "ping"; then
        print_error "ping command not found"
        echo "SKIPPED: ping not available" >> "$result_file"
        return 1
    fi
    
    {
        echo "--- Ping Latency Test ---"
        echo "Target: $PING_TARGET"
        echo "Count: $PING_COUNT"
        echo ""
    } >> "$result_file"
    
    echo "Pinging $PING_TARGET ($PING_COUNT packets)..."
    
    local cmd="ping -c $PING_COUNT $PING_TARGET"
    run_with_progress "$cmd" "$result_file"
    local exit_code=$?
    
    echo "" >> "$result_file"
    
    # Also test a few other common targets for comparison
    echo "Additional latency checks:" >> "$result_file"
    
    for target in "1.1.1.1" "8.8.4.4"; do
        if [ "$target" != "$PING_TARGET" ]; then
            echo "" >> "$result_file"
            echo "Ping to $target (5 packets):" >> "$result_file"
            local cmd="ping -c 5 $target | tail -2"
            # Since tail is inside pipe, wrap carefully
            # Actually, ping outputs multiple lines. The old script did: ping ... | tail -2 >> file
            # My run_with_progress handles >> file. I need to handle the tail pipe.
            # cmd="ping -c 5 $target | tail -2" -> eval handles the pipe.
            run_with_progress "ping -c 5 $target 2>&1 | tail -2" "$result_file"
        fi
    done
    
    echo "" >> "$result_file"
    return $exit_code
}

run_test() {
    print_header "Network Test"
    
    local result_file=$(start_test "Network Test")
    print_success "Results will be saved to: $result_file"
    
    {
        echo "Configuration:"
        echo "  Test Type:      $TEST_TYPE"
        echo "  Ping Target:    $PING_TARGET"
        echo "  Ping Count:     $PING_COUNT"
        echo "  iPerf Server:   ${IPERF_SERVER:-<not set>}"
        echo "  iPerf Port:     $IPERF_PORT"
        echo "  iPerf Duration: ${IPERF_DURATION}s"
        echo "  iPerf Parallel: $IPERF_PARALLEL streams"
        echo ""
        echo "Network Interfaces:"
        ip -br addr 2>/dev/null || ifconfig 2>/dev/null | grep -E "^[a-z]|inet "
        echo ""
    } >> "$result_file"
    
    local exit_code=0
    
    case "$TEST_TYPE" in
        all)
            run_latency "$result_file" || exit_code=1
            run_speedtest "$result_file" || exit_code=1
            run_iperf "$result_file" || true  # Don't fail if no iperf server
            ;;
        speedtest)
            run_speedtest "$result_file" || exit_code=1
            ;;
        iperf)
            run_iperf "$result_file" || exit_code=1
            ;;
        latency)
            run_latency "$result_file" || exit_code=1
            ;;
        *)
            print_error "Unknown test type: $TEST_TYPE"
            echo "Unknown test type: $TEST_TYPE" >> "$result_file"
            exit_code=1
            ;;
    esac
    
    end_test "$result_file" $exit_code
    
    if [ $exit_code -eq 0 ]; then
        print_success "Network test completed successfully"
    else
        print_warning "Network test completed with some errors"
    fi
    
    echo ""
    echo "Results saved to: $result_file"
    return $exit_code
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        --run) run_test ;;
        --configure|"") configure_test ;;
        *) echo "Usage: $0 [--run|--configure]"; exit 1 ;;
    esac
fi
