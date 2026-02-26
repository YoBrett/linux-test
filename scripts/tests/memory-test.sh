#!/bin/bash
######################################################################################
## PROGRAM   : memory-test.sh
## PROGRAMER : Brett Collingwood
## MUSE      : Kit
## VERSION   : 1.2.0
## DATE      : 2026-02-23
## PURPOSE   : Memory Bandwidth and Stability Tests (Sysbench, MBW, Memtester)
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
TEST_SIZE="1G"
ITERATIONS=3
SYSBENCH_THREADS=$(nproc)
SYSBENCH_TIME=30

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
        cmd=(dialog --clear --backtitle "Linux Test Suite - Memory Test" \
            --title "Memory Test Configuration" \
            --menu "Current Settings:\n\n1) Test Type:        $TEST_TYPE\n2) Test Size:        $TEST_SIZE\n3) Iterations:       $ITERATIONS\n4) Sysbench Threads: $SYSBENCH_THREADS\n5) Sysbench Time:    ${SYSBENCH_TIME}s\n\nSelect option to change or run:" 22 60 8)
        
        options=(
            1 "Test Type (all, sysbench, memtester, mbw)"
            2 "Test Size (e.g., 512M, 1G)"
            3 "Iterations"
            4 "Sysbench Threads"
            5 "Sysbench Duration (seconds)"
            R "Run test with current settings"
            Q "Return to main menu"
        )
        
        choice=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
        
        case $choice in
            1)
                tt=$(dialog --clear --backtitle "Linux Test Suite - Memory Test" \
                    --title "Select Test Type" \
                    --menu "Choose memory test type:" 15 50 4 \
                    all "Run all memory tests" \
                    sysbench "Sysbench memory bench" \
                    memtester "Memory stability/error" \
                    mbw "Memory bandwidth (mbw)" \
                    2>&1 >/dev/tty)
                [[ -n "$tt" ]] && TEST_TYPE=$tt
                ;;
            2)
                val=$(dialog --clear --backtitle "Linux Test Suite - Memory Test" \
                    --title "Test Size" \
                    --inputbox "Enter test size (e.g., 512M, 1G):" 8 40 "$TEST_SIZE" \
                    2>&1 >/dev/tty)
                [[ -n "$val" ]] && TEST_SIZE=$val
                ;;
            3)
                val=$(dialog --clear --backtitle "Linux Test Suite - Memory Test" \
                    --title "Iterations" \
                    --inputbox "Enter number of iterations:" 8 40 "$ITERATIONS" \
                    2>&1 >/dev/tty)
                [[ "$val" =~ ^[0-9]+$ ]] && ITERATIONS=$val
                ;;
            4)
                val=$(dialog --clear --backtitle "Linux Test Suite - Memory Test" \
                    --title "Sysbench Threads" \
                    --inputbox "Enter number of threads (1-$(nproc)):" 8 40 "$SYSBENCH_THREADS" \
                    2>&1 >/dev/tty)
                [[ "$val" =~ ^[0-9]+$ ]] && SYSBENCH_THREADS=$val
                ;;
            5)
                val=$(dialog --clear --backtitle "Linux Test Suite - Memory Test" \
                    --title "Sysbench Duration" \
                    --inputbox "Enter duration in seconds:" 8 40 "$SYSBENCH_TIME" \
                    2>&1 >/dev/tty)
                [[ "$val" =~ ^[0-9]+$ ]] && SYSBENCH_TIME=$val
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
        echo "  Memory Test Configuration"
        echo "=============================================="
        echo ""
        echo "Current Settings:"
        echo "  1) Test Type:        $TEST_TYPE"
        echo "  2) Test Size:        $TEST_SIZE"
        echo "  3) Iterations:       $ITERATIONS"
        echo "  4) Sysbench Threads: $SYSBENCH_THREADS"
        echo "  5) Sysbench Time:    ${SYSBENCH_TIME}s"
        echo ""
        echo "Available tests:"
        echo "     all       - Run all memory tests"
        echo "     sysbench  - Sysbench memory benchmark"
        echo "     memtester - Memory stability/error test"
        echo "     mbw       - Memory bandwidth (mbw)"
        echo ""
        echo "  r) Run test with current settings"
        echo "  q) Return to main menu"
        echo ""
        echo "              *** Use Not Intended For Benchmarking Purposes ***"
        echo ""
        read -p "Select option: " choice
        
        case $choice in
            1)
                read -p "Enter test type (all/sysbench/memtester/mbw): " val
                [[ -n "$val" ]] && TEST_TYPE=$val
                ;;
            2)
                read -p "Enter test size (e.g., 512M, 1G): " val
                [[ -n "$val" ]] && TEST_SIZE=$val
                ;;
            3)
                read -p "Enter iterations: " val
                [[ "$val" =~ ^[0-9]+$ ]] && ITERATIONS=$val
                ;;
            4)
                read -p "Enter sysbench threads (1-$(nproc)): " val
                [[ "$val" =~ ^[0-9]+$ ]] && SYSBENCH_THREADS=$val
                ;;
            5)
                read -p "Enter sysbench duration (seconds): " val
                [[ "$val" =~ ^[0-9]+$ ]] && SYSBENCH_TIME=$val
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

# Convert size string to MB for mbw
size_to_mb() {
    local size="$1"
    local num="${size%[GgMmKk]*}"
    local unit="${size##*[0-9]}"
    
    case "$unit" in
        G|g) echo $((num * 1024)) ;;
        M|m) echo "$num" ;;
        K|k) echo $((num / 1024)) ;;
        *)   echo "$num" ;;
    esac
}

# Run sysbench memory test
run_sysbench() {
    local result_file="$1"
    
    print_header "Sysbench Memory Test"
    
    if ! require_dependency "sysbench"; then
        echo "SKIPPED: sysbench not available" >> "$result_file"
        return 1
    fi
    
    {
        echo "--- Sysbench Memory Test ---"
        echo "Threads: $SYSBENCH_THREADS"
        echo "Duration: ${SYSBENCH_TIME}s"
        echo ""
    } >> "$result_file"
    
    echo "Running sysbench memory test for ${SYSBENCH_TIME}s with $SYSBENCH_THREADS threads..."
    
    local cmd="sysbench memory --threads=$SYSBENCH_THREADS --time=$SYSBENCH_TIME --memory-block-size=1K --memory-total-size=100G run"
    run_with_progress "$cmd" "$result_file"
    
    local exit_code=$?
    echo "" >> "$result_file"
    
    return $exit_code
}

# Run memtester
run_memtester() {
    local result_file="$1"
    
    print_header "Memtester (Memory Stability Test)"
    
    if ! require_dependency "memtester"; then
        echo "SKIPPED: memtester not available" >> "$result_file"
        return 1
    fi
    
    # Memtester needs size in MB or just a number
    local size_mb=$(size_to_mb "$TEST_SIZE")
    
    {
        echo "--- Memtester ---"
        echo "Size: ${size_mb}M"
        echo "Iterations: $ITERATIONS"
        echo ""
    } >> "$result_file"
    
    echo "Running memtester with ${size_mb}M for $ITERATIONS iterations..."
    print_warning "This may take a while depending on size and iterations."
    
    local cmd="memtester ${size_mb}M $ITERATIONS"
    run_with_progress "$cmd" "$result_file"
    
    local exit_code=$?
    echo "" >> "$result_file"
    
    return $exit_code
}

# Run mbw (memory bandwidth)
run_mbw() {
    local result_file="$1"
    
    print_header "MBW (Memory Bandwidth Test)"
    
    if ! require_dependency "mbw"; then
        echo "SKIPPED: mbw not available" >> "$result_file"
        return 1
    fi
    
    local size_mb=$(size_to_mb "$TEST_SIZE")
    
    {
        echo "--- MBW (Memory Bandwidth) ---"
        echo "Array Size: ${size_mb}M"
        echo "Iterations: $ITERATIONS"
        echo ""
    } >> "$result_file"
    
    echo "Running mbw with ${size_mb}MB array for $ITERATIONS iterations..."
    
    # Run all three mbw tests: MEMCPY, DUMB, MCBLOCK
    local cmd="mbw -n $ITERATIONS $size_mb"
    run_with_progress "$cmd" "$result_file"
    
    local exit_code=$?
    echo "" >> "$result_file"
    
    return $exit_code
}

run_test() {
    print_header "Memory Test"
    
    local result_file=$(start_test "Memory Test")
    print_success "Results will be saved to: $result_file"
    
    {
        echo "Configuration:"
        echo "  Test Type:        $TEST_TYPE"
        echo "  Test Size:        $TEST_SIZE"
        echo "  Iterations:       $ITERATIONS"
        echo "  Sysbench Threads: $SYSBENCH_THREADS"
        echo "  Sysbench Time:    ${SYSBENCH_TIME}s"
        echo ""
    } >> "$result_file"
    
    local exit_code=0
    
    case "$TEST_TYPE" in
        all)
            run_sysbench "$result_file" || exit_code=1
            run_mbw "$result_file" || exit_code=1
            run_memtester "$result_file" || exit_code=1
            ;;
        sysbench)
            run_sysbench "$result_file" || exit_code=1
            ;;
        memtester)
            run_memtester "$result_file" || exit_code=1
            ;;
        mbw)
            run_mbw "$result_file" || exit_code=1
            ;;
        *)
            print_error "Unknown test type: $TEST_TYPE"
            echo "Unknown test type: $TEST_TYPE" >> "$result_file"
            exit_code=1
            ;;
    esac
    
    end_test "$result_file" $exit_code
    
    if [ $exit_code -eq 0 ]; then
        print_success "Memory test completed successfully"
    else
        print_warning "Memory test completed with some errors"
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
