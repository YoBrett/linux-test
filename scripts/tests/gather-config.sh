#!/bin/bash
######################################################################################
## PROGRAM   : gather-config.sh
## PROGRAMER : Brett Collingwood
## MUSE      : Kit
## VERSION   : 1.0.0
## DATE      : 2026-02-25
## PURPOSE   : Gather system configuration (dmidecode, lscpu, etc.)
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

# Check for dialog
USE_DIALOG=false
if command -v dialog &> /dev/null; then
    USE_DIALOG=true
fi

# Flag for skipping privileged commands
SKIP_PRIVILEGED=false

configure_test() {
    if [ "$USE_DIALOG" = true ]; then
        configure_test_dialog
    else
        configure_test_text
    fi
}

configure_test_dialog() {
    while true; do
        local priv_status="Enabled"
        [ "$SKIP_PRIVILEGED" = true ] && priv_status="Disabled"
        
        dialog --clear --backtitle "Linux Test Suite - Gather Config" \
            --title "Gather Configuration" \
            --msgbox "This script gathers system information including:\n\n- DMI/BIOS details (sudo dmidecode -t bios)\n- CPU info\n- Memory info\n- OS/Kernel info\n\nPrivileged Commands: $priv_status\n\nUse Not Intended For Benchmarking Purposes" 16 60
            
        choice=$(dialog --clear --backtitle "Linux Test Suite - Gather Config" \
            --title "Gather Configuration" \
            --menu "Select option:" 14 50 4 \
            R "Run configuration gathering" \
            P "Toggle privileged commands ($priv_status)" \
            Q "Return to main menu" \
            2>&1 >/dev/tty)
            
        case $choice in
            R)
                clear
                run_test
                echo ""
                read -p "Press Enter to continue..."
                ;;
            P)
                if [ "$SKIP_PRIVILEGED" = true ]; then
                    SKIP_PRIVILEGED=false
                else
                    SKIP_PRIVILEGED=true
                fi
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
        local priv_status="Enabled"
        [ "$SKIP_PRIVILEGED" = true ] && priv_status="Disabled"
        
        echo "=============================================="
        echo "  Gather Configuration"
        echo "=============================================="
        echo ""
        echo "This script gathers system information including:"
        echo "  - DMI/BIOS details (sudo dmidecode -t bios)"
        echo "  - CPU info"
        echo "  - Memory info"
        echo "  - OS/Kernel info"
        echo ""
        echo "Privileged Commands: $priv_status"
        echo ""
        echo "  r) Run configuration gathering"
        echo "  p) Toggle privileged commands"
        echo "  q) Return to main menu"
        echo ""
        echo "              *** Use Not Intended For Benchmarking Purposes ***"
        echo ""
        read -p "Select option: " choice
        
        case $choice in
            r|R)
                run_test
                read -p "Press Enter to continue..."
                ;;
            p|P)
                if [ "$SKIP_PRIVILEGED" = true ]; then
                    SKIP_PRIVILEGED=false
                    echo "Privileged commands enabled"
                else
                    SKIP_PRIVILEGED=true
                    echo "Privileged commands disabled"
                fi
                sleep 1
                ;;
            q|Q)
                return 0
                ;;
            *)
                echo "Invalid option"
                sleep 1
                ;;
        esac
    done
}

# Run a command, handling privileged commands appropriately
run_config_command() {
    local desc="$1"
    local cmd="$2"
    local result_file="$3"
    local is_privileged="${4:-false}"
    
    print_header "$desc"
    
    {
        echo ""
        echo "=== $desc ==="
        echo "Command: $cmd"
        echo "----------------------------------------------"
    } >> "$result_file"
    
    # Check if this is a privileged command and if we should skip
    if [ "$is_privileged" = true ] && [ "$SKIP_PRIVILEGED" = true ]; then
        echo "SKIPPED (privileged commands disabled)"
        echo "SKIPPED: Privileged commands disabled by user" >> "$result_file"
        return 0
    fi
    
    # If privileged, check sudo availability
    if [ "$is_privileged" = true ]; then
        if ! command -v sudo &> /dev/null; then
            echo "SKIPPED (sudo not available)"
            echo "SKIPPED: sudo not available" >> "$result_file"
            return 0
        fi
    fi
    
    echo "Running: $cmd"
    run_with_progress "$cmd" "$result_file"
    
    echo "" >> "$result_file"
}

run_test() {
    print_header "Gathering System Configuration"
    
    local result_file=$(start_test "System Configuration")
    print_success "Results will be saved to: $result_file"
    
    # Check for sudo if not skipping privileged
    if [ "$SKIP_PRIVILEGED" != true ]; then
        if ! command -v sudo &> /dev/null; then
            print_warning "sudo not available - some commands will be skipped"
            print_warning "Use 'Toggle privileged commands' option to disable them"
        fi
    fi
    
    # Ensure dependencies
    if ! check_command "dmidecode"; then
        require_dependency "dmidecode"
    fi
    if ! check_command "lsdev"; then
        require_dependency "lsdev" "procinfo"
    fi
    
    # Define commands to run
    # Format: "Description|Command|Privileged(true/false)"
    local commands=(
        "BIOS Information|sudo dmidecode -t bios|true"
        "System Information|sudo dmidecode -t system|true"
        "Baseboard Information|sudo dmidecode -t baseboard|true"
        "Chassis Information|sudo dmidecode -t chassis|true"
        "Processor Information|sudo dmidecode -t processor|true"
        "Memory Device Information|sudo dmidecode -t memory|true"
        "CPU Topology|lscpu|false"
        "Block Devices|lsblk -a|false"
        "PCI Devices|lspci|false"
        "USB Devices|lsusb|false"
        "Kernel Modules|lsmod|false"
        "OS Release|cat /etc/os-release|false"
        "Kernel Version|uname -a|false"
        "Memory Usage|free -h|false"
        "Disk Usage|df -h|false"
        "Network Interfaces|ip addr|false"
        "Installed Hardware (lsdev)|lsdev|false"
    )
    
    for item in "${commands[@]}"; do
        local desc="${item%%|*}"
        local rest="${item#*|}"
        local cmd="${rest%%|*}"
        local privileged="${rest##*|}"
        
        run_config_command "$desc" "$cmd" "$result_file" "$privileged"
    done
    
    end_test "$result_file" 0
    
    print_success "Configuration gathering complete"
    echo "Results saved to: $result_file"
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        --run) run_test ;;
        --configure|"") configure_test ;;
        --no-sudo)
            SKIP_PRIVILEGED=true
            run_test
            ;;
        *) echo "Usage: $0 [--run|--configure|--no-sudo]"; exit 1 ;;
    esac
fi
