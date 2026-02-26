#!/bin/bash
######################################################################################
## PROGRAM   : stress-test.sh
## PROGRAMER : Brett Collingwood
## MUSE      : Kit
## VERSION   : 1.0.0
## DATE      : 2026-02-25
## PURPOSE   : CPU/Memory stress test (Stress-ng)
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
CPU_WORKERS=$(nproc)
MEMORY_WORKERS=2
MEMORY_SIZE="1G"
DURATION=60

# Check for dialog
USE_DIALOG=false
if command -v dialog &> /dev/null; then
    USE_DIALOG=true
fi

# Show configuration menu
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
        cmd=(dialog --clear --backtitle "Linux Test Suite - Stress Test" \
            --title "Stress Test Configuration" \
            --menu "Current Settings:\n\n1) CPU Workers:    $CPU_WORKERS\n2) Memory Workers: $MEMORY_WORKERS\n3) Memory Size:    $MEMORY_SIZE\n4) Duration:       ${DURATION}s\n\nSelect option to change or run:" 20 60 6)
        
        options=(
            1 "CPU Workers"
            2 "Memory Workers"
            3 "Memory Size (e.g., 512M, 1G)"
            4 "Duration (seconds)"
            R "Run test with current settings"
            Q "Return to main menu"
        )
        
        choice=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
        
        case $choice in
            1)
                val=$(dialog --clear --backtitle "Linux Test Suite - Stress Test" \
                    --title "CPU Workers" \
                    --inputbox "Enter number of CPU workers (1-$(nproc)):" 8 40 "$CPU_WORKERS" \
                    2>&1 >/dev/tty)
                [[ "$val" =~ ^[0-9]+$ ]] && CPU_WORKERS=$val
                ;;
            2)
                val=$(dialog --clear --backtitle "Linux Test Suite - Stress Test" \
                    --title "Memory Workers" \
                    --inputbox "Enter number of memory workers:" 8 40 "$MEMORY_WORKERS" \
                    2>&1 >/dev/tty)
                [[ "$val" =~ ^[0-9]+$ ]] && MEMORY_WORKERS=$val
                ;;
            3)
                val=$(dialog --clear --backtitle "Linux Test Suite - Stress Test" \
                    --title "Memory Size" \
                    --inputbox "Enter memory size per worker (e.g., 512M, 1G):" 8 40 "$MEMORY_SIZE" \
                    2>&1 >/dev/tty)
                [[ -n "$val" ]] && MEMORY_SIZE=$val
                ;;
            4)
                val=$(dialog --clear --backtitle "Linux Test Suite - Stress Test" \
                    --title "Duration" \
                    --inputbox "Enter duration in seconds:" 8 40 "$DURATION" \
                    2>&1 >/dev/tty)
                [[ "$val" =~ ^[0-9]+$ ]] && DURATION=$val
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
        echo "  Stress Test Configuration"
        echo "=============================================="
        echo ""
        echo "Current Settings:"
        echo "  1) CPU Workers:    $CPU_WORKERS"
        echo "  2) Memory Workers: $MEMORY_WORKERS"
        echo "  3) Memory Size:    $MEMORY_SIZE"
        echo "  4) Duration:       ${DURATION}s"
        echo ""
        echo "  r) Run test with current settings"
        echo "  q) Return to main menu"
        echo ""
        echo "              *** Use Not Intended For Benchmarking Purposes ***"
        echo ""
        read -p "Select option: " choice
        
        case $choice in
            1)
                read -p "Enter CPU workers (1-$(nproc), current: $CPU_WORKERS): " val
                [[ "$val" =~ ^[0-9]+$ ]] && CPU_WORKERS=$val
                ;;
            2)
                read -p "Enter memory workers (current: $MEMORY_WORKERS): " val
                [[ "$val" =~ ^[0-9]+$ ]] && MEMORY_WORKERS=$val
                ;;
            3)
                read -p "Enter memory size (e.g., 512M, 1G, current: $MEMORY_SIZE): " val
                [[ -n "$val" ]] && MEMORY_SIZE=$val
                ;;
            4)
                read -p "Enter duration in seconds (current: $DURATION): " val
                [[ "$val" =~ ^[0-9]+$ ]] && DURATION=$val
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

# Run the stress test
run_test() {
    print_header "Stress Test (stress-ng)"
    
    # Check for stress-ng
    if ! require_dependency "stress-ng"; then
        return 1
    fi
    
    # Start test
    local result_file=$(start_test "Stress Test")
    print_success "Results will be saved to: $result_file"
    
    # Log configuration
    {
        echo "Configuration:"
        echo "  CPU Workers:    $CPU_WORKERS"
        echo "  Memory Workers: $MEMORY_WORKERS"
        echo "  Memory Size:    $MEMORY_SIZE"
        echo "  Duration:       ${DURATION}s"
        echo ""
        echo "Running stress-ng..."
        echo ""
    } >> "$result_file"
    
    # Run stress-ng
    print_header "Running stress test for ${DURATION} seconds..."
    
    local cmd="stress-ng --cpu $CPU_WORKERS --vm $MEMORY_WORKERS --vm-bytes $MEMORY_SIZE --timeout ${DURATION}s --metrics-brief"
    run_with_progress "$cmd" "$result_file"
    local exit_code=$?
    
    # End test
    end_test "$result_file" $exit_code
    
    if [ $exit_code -eq 0 ]; then
        print_success "Stress test completed successfully"
    else
        print_error "Stress test failed with exit code $exit_code"
    fi
    
    echo ""
    echo "Results saved to: $result_file"
    return $exit_code
}

# Main
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        --run)
            run_test
            ;;
        --configure|"")
            configure_test
            ;;
        *)
            echo "Usage: $0 [--run|--configure]"
            exit 1
            ;;
    esac
fi
