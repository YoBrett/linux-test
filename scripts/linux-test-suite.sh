#!/bin/bash
######################################################################################
## PROGRAM   : linux-test-suite.sh
## PROGRAMER : Brett Collingwood
## MUSE      : Kit
## VERSION   : 1.0.0
## DATE      : 2026-02-23
## PURPOSE   : Master script for Linux Test Suite (Menu System)
## #---------------------------------------------------------------------------------#
## THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
## INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
## PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
## HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
## OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
## SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
######################################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# Test scripts
TESTS_DIR="$SCRIPT_DIR/tests"

# Check for dialog/whiptail
USE_DIALOG=false
USE_WHIPTAIL=false

if command -v dialog &> /dev/null; then
    USE_DIALOG=true
elif command -v whiptail &> /dev/null; then
    USE_WHIPTAIL=true
fi

# SAR Logging state
SAR_PID=""
SAR_FILE=""

# ===========================================
# Global Cleanup Trap
# ===========================================
cleanup() {
    # Stop SAR logging if running
    if [ -n "$SAR_PID" ]; then
        stop_sar_and_report
    fi
}

# Set trap for cleanup on exit, interrupt, or termination
trap cleanup EXIT SIGTERM SIGINT

# ===========================================
# Dependency Check
# ===========================================
# Define all required dependencies: "command:package"
# If package name differs from command, use "command:package"
# If they match, just use "command"
DEPENDENCIES=(
    "dialog"
    "dmidecode"
    "stress-ng"
    "sysbench"
    "memtester"
    "mbw"
    "fio"
    "iperf3"
    "speedtest-cli"
    "7z:p7zip-full"
    "openssl"
    "ping"
    "sar:sysstat"
    "lsdev:procinfo"
    "bc"
)

# List of available tests
AVAILABLE_TESTS=(
    "gather-config:Gather Config:System hardware info (dmidecode)"
    "stress-test:Stress Test:CPU/Memory stress (stress-ng)"
    "cpu-benchmark:CPU Benchmark:Performance benchmarks"
    "memory-test:Memory Test:Bandwidth & stability"
    "storage-test:Storage Test:I/O performance"
    "network-test:Network Test:Bandwidth & latency"
    "thermal-monitor:Thermal Monitor:Temperature monitoring"
)

# ===========================================
# SAR Logging Functions
# ===========================================

# Start SAR logging if not already running
start_sar_logging() {
    if [ -z "$SAR_PID" ]; then
        if check_command "sar"; then
            # Use mktemp for secure temp file creation
            SAR_FILE=$(mktemp /tmp/linux-test-sar.XXXXXX.data)
            log_verbose "Starting SAR logging to $SAR_FILE"
            # Record statistics every 1 second to binary file
            sar -o "$SAR_FILE" 1 >/dev/null 2>&1 &
            SAR_PID=$!
            # Disown so it doesn't clutter job control
            disown $SAR_PID 2>/dev/null
        else
            log_verbose "SAR not available, skipping system monitoring"
        fi
    fi
}

# Stop SAR logging and generate report
stop_sar_and_report() {
    if [ -n "$SAR_PID" ]; then
        log_verbose "Stopping SAR process (PID: $SAR_PID)"
        # Kill the background sar process
        kill $SAR_PID 2>/dev/null
        wait $SAR_PID 2>/dev/null
        
        # Generate text report from binary data
        local report_file="$RESULTS_DIR/system_monitor_report_$(get_file_timestamp).txt"
        
        if [ "$QUIET" != true ]; then
            echo "Generating system monitor report..."
        fi
        
        if [ -f "$SAR_FILE" ]; then
            {
                echo "======================================================================"
                echo "                     System Monitor Report (sar)"
                echo "       *** Use Not Intended For Benchmarking Purposes ***"
                echo "======================================================================"
                echo "Capture File: $SAR_FILE"
                echo "Generated:    $(get_timestamp)"
                echo ""
                # Dump all stats (-A)
                sar -A -f "$SAR_FILE" 2>/dev/null || echo "Error reading SAR data"
            } > "$report_file"
            
            # Clean up binary file
            rm -f "$SAR_FILE"
            
            if [ "$QUIET" != true ]; then
                echo "Report saved to: $report_file"
            fi
        else
            if [ "$QUIET" != true ]; then
                echo "Warning: No SAR data collected."
            fi
        fi
        
        SAR_PID=""
        SAR_FILE=""
    fi
}

# Wrapper to run a test and ensure SAR is started
run_test_wrapper() {
    start_sar_logging
    # Execute the command passed as argument
    "$@"
}

# ===========================================
# Dependency Management
# ===========================================

# Check all dependencies at startup
check_all_dependencies() {
    print_header "Checking Dependencies"
    
    local missing=()
    local installed=()
    local critical_missing=false
    
    for dep in "${DEPENDENCIES[@]}"; do
        local cmd="${dep%%:*}"
        local pkg="${dep##*:}"
        [[ "$cmd" == "$pkg" ]] && pkg="$cmd"
        
        if check_command "$cmd"; then
            installed+=("$cmd")
        else
            missing+=("$cmd:$pkg")
            # Mark critical dependencies
            case "$cmd" in
                dialog|dmidecode|stress-ng)
                    critical_missing=true
                    ;;
            esac
        fi
    done
    
    # Show installed
    for cmd in "${installed[@]}"; do
        print_success "$cmd"
    done
    
    # Show missing
    if [ ${#missing[@]} -gt 0 ]; then
        echo ""
        print_warning "Missing dependencies:"
        for item in "${missing[@]}"; do
            local cmd="${item%%:*}"
            local pkg="${item##*:}"
            echo "  - $cmd (package: $pkg)"
        done
        
        if [ "$critical_missing" = true ]; then
            print_warning "Some critical dependencies are missing!"
        fi
        
        echo ""
        read -p "Do you want to install missing dependencies now? [Y/n] " choice
        case "${choice:-Y}" in
            y|Y)
                local failed=()
                for item in "${missing[@]}"; do
                    local cmd="${item%%:*}"
                    local pkg="${item##*:}"
                    if ! install_package "$pkg"; then
                        failed+=("$pkg")
                    fi
                done
                echo ""
                if [ ${#failed[@]} -gt 0 ]; then
                    print_warning "Failed to install: ${failed[*]}"
                    print_warning "Please install these packages manually."
                else
                    print_success "Dependency installation complete"
                fi
                ;;
            *)
                print_warning "Some tests may not work without all dependencies."
                ;;
        esac
    else
        print_success "All dependencies installed!"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

# ===========================================
# Menu Functions
# ===========================================

# Simple text menu (fallback)
show_text_menu() {
    while true; do
        clear
        echo "=============================================="
        echo "  Linux Test Suite v${VERSION}"
        echo "=============================================="
        echo ""
        echo "  Host: $(hostname)"
        echo "  CPU:  $(lscpu | grep 'Model name' | cut -d: -f2 | xargs 2>/dev/null || echo 'Unknown')"
        echo "  Arch: $(uname -m)"
        echo ""
        echo "=============================================="
        echo "  Linux Test Menu"
        echo "=============================================="
        echo ""
        echo "  1) Gather Config    - System hardware info (dmidecode)"
        echo "  2) Stress Test      - CPU/Memory stress (stress-ng)"
        echo "  3) CPU Benchmark    - Performance benchmarks"
        echo "  4) Memory Test      - Bandwidth & stability"
        echo "  5) Storage Test     - I/O performance"
        echo "  6) Network Test     - Bandwidth & latency"
        echo "  7) Thermal Monitor  - Temperature monitoring"
        echo ""
        echo "  a) Run ALL tests (default settings)"
        echo "  d) Check/install dependencies"
        echo "  v) View results directory"
        echo "  p) Package test suite (tar.gz)"
        echo ""
        echo "  q) Quit"
        echo ""
        echo "              *** Use Not Intended For Benchmarking Purposes ***"
        echo ""
        read -p "Select option: " choice
        
        case $choice in
            1) run_test_wrapper "$TESTS_DIR/gather-config.sh" --configure ;;
            2) run_test_wrapper "$TESTS_DIR/stress-test.sh" --configure ;;
            3) run_test_wrapper "$TESTS_DIR/cpu-benchmark.sh" --configure ;;
            4) run_test_wrapper "$TESTS_DIR/memory-test.sh" --configure ;;
            5) run_test_wrapper "$TESTS_DIR/storage-test.sh" --configure ;;
            6) run_test_wrapper "$TESTS_DIR/network-test.sh" --configure ;;
            7) run_test_wrapper "$TESTS_DIR/thermal-monitor.sh" --configure ;;
            a|A) run_test_wrapper run_all_tests ;;
            d|D) check_all_dependencies ;;
            v|V) view_results ;;
            p|P) 
                stop_sar_and_report
                package_suite 
                ;;
            q|Q) 
                echo "Goodbye!"
                exit 0 
                ;;
            *)
                print_warning "Invalid option"
                sleep 1
                ;;
        esac
    done
}

# Dialog-based menu
show_dialog_menu() {
    while true; do
        choice=$(dialog --clear --backtitle "Linux Test Suite v${VERSION} - Use Not Intended For Benchmarking Purposes" \
            --title "Linux Test Menu" \
            --menu "Select a test to configure and run:\n\nNOTE: Use Not Intended For Benchmarking Purposes" 22 65 12 \
            1 "Gather Config    - System hardware info (dmidecode)" \
            2 "Stress Test      - CPU/Memory stress (stress-ng)" \
            3 "CPU Benchmark    - Performance benchmarks" \
            4 "Memory Test      - Bandwidth & stability" \
            5 "Storage Test     - I/O performance" \
            6 "Network Test     - Bandwidth & latency" \
            7 "Thermal Monitor  - Temperature monitoring" \
            A "Run ALL tests (default settings)" \
            D "Check/install dependencies" \
            V "View results directory" \
            P "Package test suite (tar.gz)" \
            Q "Quit" \
            2>&1 >/dev/tty)

        clear
        case $choice in
            1) run_test_wrapper "$TESTS_DIR/gather-config.sh" --configure ;;
            2) run_test_wrapper "$TESTS_DIR/stress-test.sh" --configure ;;
            3) run_test_wrapper "$TESTS_DIR/cpu-benchmark.sh" --configure ;;
            4) run_test_wrapper "$TESTS_DIR/memory-test.sh" --configure ;;
            5) run_test_wrapper "$TESTS_DIR/storage-test.sh" --configure ;;
            6) run_test_wrapper "$TESTS_DIR/network-test.sh" --configure ;;
            7) run_test_wrapper "$TESTS_DIR/thermal-monitor.sh" --configure ;;
            A) run_test_wrapper run_all_tests ;;
            D) check_all_dependencies ;;
            V) view_results ;;
            P) 
                stop_sar_and_report
                package_suite 
                ;;
            Q|"") 
                echo "Goodbye!"
                exit 0 
                ;;
        esac
    done
}

# ===========================================
# Test Execution
# ===========================================

# Run all tests with default settings
run_all_tests() {
    print_header "Running All Tests"
    
    local all_results_file="$RESULTS_DIR/all_tests_$(get_file_timestamp).txt"
    
    {
        echo "=============================================="
        echo "  Linux Test Suite - Full Run"
        echo "  Version: ${VERSION}"
        echo "=============================================="
        echo ""
        echo "START TIME: $(get_timestamp)"
        echo ""
    } > "$all_results_file"
    
    for test in gather-config stress-test cpu-benchmark memory-test storage-test network-test thermal-monitor; do
        echo "Running: $test"
        echo "" >> "$all_results_file"
        echo "=== $test ===" >> "$all_results_file"
        "$TESTS_DIR/${test}.sh" --run 2>&1 | tee -a "$all_results_file"
    done
    
    {
        echo ""
        echo "=============================================="
        echo "END TIME: $(get_timestamp)"
        echo "=============================================="
    } >> "$all_results_file"
    
    print_success "All tests completed"
    echo "Combined results: $all_results_file"
    read -p "Press Enter to continue..."
}

# ===========================================
# Utility Functions
# ===========================================

# View results directory
view_results() {
    print_header "Results Directory"
    
    if [ -d "$RESULTS_DIR" ] && [ "$(ls -A $RESULTS_DIR 2>/dev/null)" ]; then
        echo "Contents of $RESULTS_DIR:"
        echo ""
        ls -lh "$RESULTS_DIR"
    else
        print_warning "No results found yet"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

# Package the test suite
package_suite() {
    print_header "Packaging Test Suite"
    
    # Delete any prior .tar.gz packages
    local old_packages=("$SCRIPT_DIR"/../linux-test-suite_*.tar.gz)
    # Also clean up old ampere packages if they exist
    if ls "$SCRIPT_DIR"/../ampere-test-suite_*.tar.gz 1> /dev/null 2>&1; then
        rm -f "$SCRIPT_DIR"/../ampere-test-suite_*.tar.gz
    fi
    
    if [ -e "${old_packages[0]}" ]; then
        echo "Removing old package(s)..."
        rm -f "$SCRIPT_DIR"/../linux-test-suite_*.tar.gz
        rm -f "$SCRIPT_DIR"/../linux-test-suite_*.tar.gz.sha256
        print_success "Old packages removed"
    fi
    
    local package_name="linux-test-suite_$(get_file_timestamp).tar.gz"
    local package_path="$SCRIPT_DIR/../$package_name"
    
    echo "Creating package: $package_name"
    
    tar -czvf "$package_path" \
        -C "$SCRIPT_DIR/.." \
        --exclude="results/*" \
        scripts/
    
    if [ $? -eq 0 ]; then
        print_success "Package created: $package_path"
        echo "Size: $(ls -lh "$package_path" | awk '{print $5}')"
        
        # Generate SHA256 checksum
        if check_command "sha256sum"; then
            sha256sum "$package_path" > "${package_path}.sha256"
            print_success "Checksum created: ${package_path}.sha256"
            echo "SHA256: $(cat "${package_path}.sha256" | awk '{print $1}')"
        elif check_command "shasum"; then
            shasum -a 256 "$package_path" > "${package_path}.sha256"
            print_success "Checksum created: ${package_path}.sha256"
        fi
    else
        print_error "Failed to create package"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

# List available tests
list_tests() {
    echo "Linux Test Suite v${VERSION} - Available Tests"
    echo "=============================================="
    echo ""
    for test_info in "${AVAILABLE_TESTS[@]}"; do
        local script="${test_info%%:*}"
        local rest="${test_info#*:}"
        local name="${rest%%:*}"
        local desc="${rest#*:}"
        printf "  %-20s %s\n" "$name" "$desc"
    done
    echo ""
    echo "Use --run-all to run all tests with default settings."
    echo "Or run the interactive menu (no arguments) to configure each test."
}

# Show help
show_help() {
    echo "Linux Test Suite v${VERSION}"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --help, -h       Show this help message"
    echo "  --version, -v    Show version"
    echo "  --text           Force text menu (no dialog/whiptail)"
    echo "  --check-deps     Check and install dependencies"
    echo "  --run-all        Run all tests with default settings"
    echo "  --list-tests     List available tests"
    echo "  --package        Create tar.gz package"
    echo "  --verbose        Enable verbose output"
    echo "  --quiet          Suppress non-essential output"
    echo "  --dry-run        Show what would be done without executing"
    echo ""
    echo "Without options, starts the interactive menu."
    echo ""
    echo "Examples:"
    echo "  $0                    # Start interactive menu"
    echo "  $0 --run-all          # Run all tests non-interactively"
    echo "  $0 --dry-run --run-all  # Preview all tests without running"
}

# ===========================================
# Main Entry Point
# ===========================================
main() {
    # Parse flags first
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --verbose)
                VERBOSE=true
                shift
                ;;
            --quiet)
                QUIET=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                print_warning "Dry run mode enabled - no commands will be executed"
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            --version|-v)
                echo "Linux Test Suite v${VERSION}"
                exit 0
                ;;
            --text)
                USE_DIALOG=false
                check_all_dependencies
                show_text_menu
                exit 0
                ;;
            --check-deps)
                check_all_dependencies
                exit 0
                ;;
            --run-all)
                start_sar_logging
                run_all_tests
                stop_sar_and_report
                exit 0
                ;;
            --list-tests)
                list_tests
                exit 0
                ;;
            --package)
                package_suite
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # No arguments - start interactive mode
    # Check dependencies on first launch
    check_all_dependencies
    
    # Re-check dialog support in case it was just installed
    if command -v dialog &> /dev/null; then
        USE_DIALOG=true
    fi

    if [ "$USE_DIALOG" = true ]; then
        show_dialog_menu
    else
        show_text_menu
    fi
}

main "$@"
