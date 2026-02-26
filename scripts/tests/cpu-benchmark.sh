#!/bin/bash
######################################################################################
## PROGRAM   : cpu-benchmark.sh
## PROGRAMER : Brett Collingwood
## MUSE      : Kit
## VERSION   : 1.0.0
## DATE      : 2026-02-25
## PURPOSE   : CPU performance benchmarks (Sysbench, 7-zip, OpenSSL)
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
SYSBENCH_THREADS=$(nproc)
SYSBENCH_TIME=30
SYSBENCH_PRIME=20000
OPENSSL_SECONDS=10

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
        cmd=(dialog --clear --backtitle "Linux Test Suite - CPU Benchmark" \
            --title "CPU Benchmark Configuration" \
            --menu "Current Settings:\n\n1) Test Type:        $TEST_TYPE\n2) Sysbench Threads: $SYSBENCH_THREADS\n3) Sysbench Time:    ${SYSBENCH_TIME}s\n4) Sysbench Prime:   $SYSBENCH_PRIME\n5) OpenSSL Seconds:  ${OPENSSL_SECONDS}s\n\nSelect option to change or run:" 22 60 8)
        
        options=(
            1 "Test Type (all, sysbench, 7zip, openssl)"
            2 "Sysbench Threads"
            3 "Sysbench Time (seconds)"
            4 "Sysbench Prime Limit"
            5 "OpenSSL Duration (seconds)"
            R "Run test with current settings"
            Q "Return to main menu"
        )
        
        choice=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
        
        case $choice in
            1)
                # Test Type Menu
                tt=$(dialog --clear --backtitle "Linux Test Suite - CPU Benchmark" \
                    --title "Select Test Type" \
                    --menu "Choose benchmark type:" 15 50 4 \
                    all "Run all benchmarks" \
                    sysbench "Sysbench CPU (prime calc)" \
                    7zip "7-Zip compression" \
                    openssl "OpenSSL crypto speed" \
                    2>&1 >/dev/tty)
                [[ -n "$tt" ]] && TEST_TYPE=$tt
                ;;
            2)
                val=$(dialog --clear --backtitle "Linux Test Suite - CPU Benchmark" \
                    --title "Sysbench Threads" \
                    --inputbox "Enter number of threads (1-$(nproc)):" 8 40 "$SYSBENCH_THREADS" \
                    2>&1 >/dev/tty)
                [[ "$val" =~ ^[0-9]+$ ]] && SYSBENCH_THREADS=$val
                ;;
            3)
                val=$(dialog --clear --backtitle "Linux Test Suite - CPU Benchmark" \
                    --title "Sysbench Duration" \
                    --inputbox "Enter duration in seconds:" 8 40 "$SYSBENCH_TIME" \
                    2>&1 >/dev/tty)
                [[ "$val" =~ ^[0-9]+$ ]] && SYSBENCH_TIME=$val
                ;;
            4)
                val=$(dialog --clear --backtitle "Linux Test Suite - CPU Benchmark" \
                    --title "Sysbench Prime Limit" \
                    --inputbox "Enter prime number limit:" 8 40 "$SYSBENCH_PRIME" \
                    2>&1 >/dev/tty)
                [[ "$val" =~ ^[0-9]+$ ]] && SYSBENCH_PRIME=$val
                ;;
            5)
                val=$(dialog --clear --backtitle "Linux Test Suite - CPU Benchmark" \
                    --title "OpenSSL Duration" \
                    --inputbox "Enter duration per test (seconds):" 8 40 "$OPENSSL_SECONDS" \
                    2>&1 >/dev/tty)
                [[ "$val" =~ ^[0-9]+$ ]] && OPENSSL_SECONDS=$val
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
        echo "  CPU Benchmark Configuration"
        echo "=============================================="
        echo ""
        echo "Current Settings:"
        echo "  1) Test Type:        $TEST_TYPE"
        echo "  2) Sysbench Threads: $SYSBENCH_THREADS"
        echo "  3) Sysbench Time:    ${SYSBENCH_TIME}s"
        echo "  4) Sysbench Prime:   $SYSBENCH_PRIME"
        echo "  5) OpenSSL Seconds:  ${OPENSSL_SECONDS}s"
        echo ""
        echo "Available tests:"
        echo "     all      - Run all benchmarks"
        echo "     sysbench - Sysbench CPU (prime calculation)"
        echo "     7zip     - 7-Zip compression benchmark"
        echo "     openssl  - OpenSSL cryptographic speed test"
        echo ""
        echo "  r) Run test with current settings"
        echo "  q) Return to main menu"
        echo ""
        echo "              *** Use Not Intended For Benchmarking Purposes ***"
        echo ""
        read -p "Select option: " choice
        
        case $choice in
            1)
                read -p "Enter test type (all/sysbench/7zip/openssl): " val
                [[ -n "$val" ]] && TEST_TYPE=$val
                ;;
            2)
                read -p "Enter sysbench threads (1-$(nproc)): " val
                [[ "$val" =~ ^[0-9]+$ ]] && SYSBENCH_THREADS=$val
                ;;
            3)
                read -p "Enter sysbench duration (seconds): " val
                [[ "$val" =~ ^[0-9]+$ ]] && SYSBENCH_TIME=$val
                ;;
            4)
                read -p "Enter sysbench prime limit: " val
                [[ "$val" =~ ^[0-9]+$ ]] && SYSBENCH_PRIME=$val
                ;;
            5)
                read -p "Enter OpenSSL test duration (seconds): " val
                [[ "$val" =~ ^[0-9]+$ ]] && OPENSSL_SECONDS=$val
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

# Run sysbench CPU benchmark
run_sysbench() {
    local result_file="$1"
    
    print_header "Sysbench CPU Benchmark"
    
    if ! require_dependency "sysbench"; then
        echo "SKIPPED: sysbench not available" >> "$result_file"
        return 1
    fi
    
    {
        echo "--- Sysbench CPU Benchmark ---"
        echo "Threads: $SYSBENCH_THREADS"
        echo "Duration: ${SYSBENCH_TIME}s"
        echo "Prime Limit: $SYSBENCH_PRIME"
        echo ""
    } >> "$result_file"
    
    echo "Running sysbench CPU test (${SYSBENCH_TIME}s, $SYSBENCH_THREADS threads)..."
    
    local cmd="sysbench cpu --threads=$SYSBENCH_THREADS --time=$SYSBENCH_TIME --cpu-max-prime=$SYSBENCH_PRIME run"
    run_with_progress "$cmd" "$result_file"
    
    local exit_code=$?
    echo "" >> "$result_file"
    
    return $exit_code
}

# Run 7-Zip benchmark
run_7zip() {
    local result_file="$1"
    
    print_header "7-Zip Compression Benchmark"
    
    # 7z can be '7z' or '7za' or '7zz'
    local zip_cmd=""
    if check_command "7z"; then
        zip_cmd="7z"
    elif check_command "7za"; then
        zip_cmd="7za"
    elif check_command "7zz"; then
        zip_cmd="7zz"
    else
        print_warning "7-Zip not found. Attempting to install..."
        if install_package "p7zip-full"; then
            zip_cmd="7z"
        elif install_package "p7zip"; then
            zip_cmd="7za"
        else
            echo "SKIPPED: 7-Zip not available" >> "$result_file"
            return 1
        fi
    fi
    
    {
        echo "--- 7-Zip Compression Benchmark ---"
        echo "Command: $zip_cmd b"
        echo ""
    } >> "$result_file"
    
    echo "Running 7-Zip benchmark (this may take a minute)..."
    
    local cmd="$zip_cmd b"
    run_with_progress "$cmd" "$result_file"
    
    local exit_code=$?
    echo "" >> "$result_file"
    
    return $exit_code
}

# Run OpenSSL speed benchmark
run_openssl() {
    local result_file="$1"
    
    print_header "OpenSSL Cryptographic Benchmark"
    
    if ! check_command "openssl"; then
        print_error "OpenSSL not found"
        echo "SKIPPED: openssl not available" >> "$result_file"
        return 1
    fi
    
    {
        echo "--- OpenSSL Cryptographic Benchmark ---"
        echo "Duration per test: ${OPENSSL_SECONDS}s"
        echo "Threads: $(nproc)"
        echo ""
    } >> "$result_file"
    
    # Test various algorithms
    local algorithms=("aes-256-cbc" "sha256" "sha512" "rsa2048" "rsa4096")
    
    for algo in "${algorithms[@]}"; do
        echo "Testing $algo..."
        {
            echo "=== $algo ==="
        } >> "$result_file"
        
        local cmd=""
        if [[ "$algo" == rsa* ]]; then
            # RSA tests use different syntax
            cmd="openssl speed -seconds $OPENSSL_SECONDS -multi $(nproc) $algo"
        else
            cmd="openssl speed -seconds $OPENSSL_SECONDS -multi $(nproc) -evp $algo"
        fi
        
        run_with_progress "$cmd" "$result_file"
        echo "" >> "$result_file"
    done
    
    # Also run a general speed test
    echo "Running general speed test..."
    {
        echo "=== General Speed Test ==="
    } >> "$result_file"
    
    # pipe tail -30 inside the command string so it gets logged properly
    local cmd="openssl speed -seconds $OPENSSL_SECONDS -multi $(nproc) 2>&1 | tail -30"
    run_with_progress "$cmd" "$result_file"
    
    echo "" >> "$result_file"
    return 0
}

run_test() {
    print_header "CPU Benchmark"
    
    local result_file=$(start_test "CPU Benchmark")
    print_success "Results will be saved to: $result_file"
    
    {
        echo "Configuration:"
        echo "  Test Type:        $TEST_TYPE"
        echo "  Sysbench Threads: $SYSBENCH_THREADS"
        echo "  Sysbench Time:    ${SYSBENCH_TIME}s"
        echo "  Sysbench Prime:   $SYSBENCH_PRIME"
        echo "  OpenSSL Seconds:  ${OPENSSL_SECONDS}s"
        echo "  CPU Cores:        $(nproc)"
        echo ""
    } >> "$result_file"
    
    local exit_code=0
    
    case "$TEST_TYPE" in
        all)
            run_sysbench "$result_file" || exit_code=1
            run_7zip "$result_file" || exit_code=1
            run_openssl "$result_file" || exit_code=1
            ;;
        sysbench)
            run_sysbench "$result_file" || exit_code=1
            ;;
        7zip)
            run_7zip "$result_file" || exit_code=1
            ;;
        openssl)
            run_openssl "$result_file" || exit_code=1
            ;;
        *)
            print_error "Unknown test type: $TEST_TYPE"
            echo "Unknown test type: $TEST_TYPE" >> "$result_file"
            exit_code=1
            ;;
    esac
    
    end_test "$result_file" $exit_code
    
    if [ $exit_code -eq 0 ]; then
        print_success "CPU benchmark completed successfully"
    else
        print_warning "CPU benchmark completed with some errors"
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
