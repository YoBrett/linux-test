#!/bin/bash
######################################################################################
## PROGRAM   : common.sh
## PROGRAMER : Brett Collingwood
## MUSE      : Kit
## VERSION   : 1.0.0
## DATE      : 2026-02-25
## PURPOSE   : Shared functions for Linux Test Suite
## #---------------------------------------------------------------------------------#
## THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
## INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
## PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
## HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
## OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
## SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
######################################################################################

# ===========================================
# Global Version (centralized)
# ===========================================
VERSION="1.0.0"

# ===========================================
# Verbosity Control
# ===========================================
VERBOSE=false
QUIET=false
DRY_RUN=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$SCRIPT_DIR/results"

# Ensure results directory exists
mkdir -p "$RESULTS_DIR"

# ===========================================
# Input Validation Functions
# ===========================================

# Validate that input is a positive integer
# Usage: validate_positive_int "value"
validate_positive_int() {
    local val="$1"
    [[ "$val" =~ ^[0-9]+$ ]] && [ "$val" -gt 0 ]
}

# Validate that input is a non-negative integer
# Usage: validate_non_negative_int "value"
validate_non_negative_int() {
    local val="$1"
    [[ "$val" =~ ^[0-9]+$ ]]
}

# Validate that path exists and is a writable directory
# Usage: validate_writable_path "/path/to/dir"
validate_writable_path() {
    local path="$1"
    [[ -d "$path" ]] && [[ -w "$path" ]]
}

# Validate that path is safe (no command injection characters)
# Usage: validate_safe_path "/path/to/dir"
validate_safe_path() {
    local path="$1"
    # Reject paths with dangerous characters: ; | & $ ` newlines
    # Using case statement for better compatibility
    case "$path" in
        *\;*|*\|*|*\&*|*\$*|*\`*|*$'\n'*)
            return 1
            ;;
        *)
            return 0
            ;;
    esac
}

# Validate size string (e.g., 512M, 1G, 4K)
# Usage: validate_size_string "1G"
validate_size_string() {
    local size="$1"
    [[ "$size" =~ ^[0-9]+[KkMmGgTt]?$ ]]
}

# Validate IP address or hostname
# Usage: validate_host "192.168.1.1" or validate_host "example.com"
validate_host() {
    local host="$1"
    # Basic check: alphanumeric, dots, hyphens only
    [[ "$host" =~ ^[a-zA-Z0-9.-]+$ ]]
}

# Sanitize a string for safe use in commands (escape special chars)
# Usage: sanitized=$(sanitize_string "$input")
sanitize_string() {
    local input="$1"
    # Remove dangerous characters
    echo "$input" | tr -d ';|&$`\\'
}

# ===========================================
# Sudo Check
# ===========================================

# Check if we can run sudo commands
# Usage: check_sudo_available
check_sudo_available() {
    if command -v sudo &> /dev/null; then
        # Try a harmless sudo command
        if sudo -n true 2>/dev/null; then
            return 0  # Passwordless sudo available
        else
            return 1  # Sudo exists but needs password
        fi
    else
        return 2  # Sudo not installed
    fi
}

# Run command with sudo if available, warn if not
# Usage: run_privileged "command"
run_privileged() {
    local cmd="$1"
    if check_sudo_available; then
        eval "sudo $cmd"
    else
        print_warning "Sudo not available or requires password. Skipping: $cmd"
        return 1
    fi
}

# ===========================================
# Timestamp Functions
# ===========================================

# Get timestamp for filenames
get_file_timestamp() {
    date +%Y%m%d_%H%M%S
}

# Get human-readable timestamp
get_timestamp() {
    date "+%Y-%m-%d %H:%M:%S %Z"
}

# ===========================================
# Test Logging Functions
# ===========================================

# Start a test - creates result file and writes header
# Usage: start_test "Test Name" 
# Returns: result file path via echo
start_test() {
    local test_name="$1"
    local safe_name=$(echo "$test_name" | tr ' ' '_' | tr '[:upper:]' '[:lower:]')
    local timestamp=$(get_file_timestamp)
    local result_file="$RESULTS_DIR/${safe_name}_${timestamp}.txt"
    local disclaimer="*** Use Not Intended For Benchmarking Purposes ***"
    
    {
        echo "======================================================================"
        printf "%*s\n" $(((${#test_name} + 70) / 2)) "$test_name"
        printf "%*s\n" $(((${#disclaimer} + 70) / 2)) "$disclaimer"
        echo "======================================================================"
        echo ""
        echo "Host:       $(hostname)"
        echo "CPU:        $(lscpu | grep 'Model name' | cut -d: -f2 | xargs 2>/dev/null || echo 'Unknown')"
        echo "Cores:      $(nproc)"
        echo "Memory:     $(free -h | awk '/^Mem:/ {print $2}')"
        echo "Kernel:     $(uname -r)"
        echo "Arch:       $(uname -m)"
        echo ""
        echo "START TIME: $(get_timestamp)"
        echo "=============================================="
        echo ""
    } > "$result_file"
    
    echo "$result_file"
}

# End a test - writes footer to result file
# Usage: end_test "/path/to/result_file" [exit_code]
end_test() {
    local result_file="$1"
    local exit_code="${2:-0}"
    local status="COMPLETED"
    
    if [ "$exit_code" -ne 0 ]; then
        status="FAILED (exit code: $exit_code)"
    fi
    
    {
        echo ""
        echo "=============================================="
        echo "END TIME:   $(get_timestamp)"
        echo "STATUS:     $status"
        echo "=============================================="
    } >> "$result_file"
}

# Log to both console and result file (DEPRECATED for run_with_progress)
# Usage: log "message" "/path/to/result_file"
log() {
    local message="$1"
    local result_file="$2"
    
    if [ "$QUIET" != true ]; then
        echo -e "$message"
    fi
    if [ -n "$result_file" ]; then
        echo "$message" >> "$result_file"
    fi
}

# Verbose log - only prints if VERBOSE=true
# Usage: log_verbose "message"
log_verbose() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}[VERBOSE]${NC} $1"
    fi
}

# ===========================================
# Progress Indicator Functions
# ===========================================

# Spinner for text mode
show_spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    
    # Print the prompt once
    echo -n "Test Underway... (Press Ctrl+C to Skip) "
    
    while ps -p $pid > /dev/null 2>&1; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
    echo ""
}

# Run command with progress indicator
# Usage: run_with_progress "command to run" "log_file"
run_with_progress() {
    local cmd="$1"
    local log_file="$2"
    
    # Dry run mode - just log what would be done
    if [ "$DRY_RUN" = true ]; then
        echo "[DRY RUN] Would execute: $cmd"
        echo "[DRY RUN] Would execute: $cmd" >> "$log_file"
        return 0
    fi
    
    # Check if we should use dialog (requires USE_DIALOG var from main script context)
    # If not set, default to false
    local use_dialog_local="${USE_DIALOG:-false}"
    
    # Start command in background
    eval "$cmd" >> "$log_file" 2>&1 &
    local pid=$!
    
    # Use a flag for cancellation instead of return in trap
    local cancelled=false
    trap "kill $pid 2>/dev/null; cancelled=true" SIGINT

    if [ "$use_dialog_local" = true ]; then
        # Dialog mode: Show infobox and wait
        dialog --infobox "\n\nTest Underway...\n(Press Ctrl+C to Skip)\n\nUse Not Intended For Benchmarking Purposes" 12 60
        wait $pid
        local ret=$?
    else
        # Text mode: Show spinner
        show_spinner $pid
        local ret=$?
    fi
    
    # Wait for process and get exit code
    wait $pid 2>/dev/null
    ret=$?
    
    # Reset trap to default
    trap - SIGINT
    
    # Handle cancellation
    if [ "$cancelled" = true ]; then
        echo '*** TEST CANCELLED BY USER ***' >> "$log_file"
        return 1
    fi
    
    return $ret
}

# ===========================================
# Dependency Management
# ===========================================

# Check if a command exists (silent check)
# Usage: check_command "cmd"
check_command() {
    command -v "$1" &> /dev/null
}

# Install a package using the system package manager
# Usage: install_package "package_name"
install_package() {
    local pkg="$1"
    
    if [ "$DRY_RUN" = true ]; then
        echo "[DRY RUN] Would install package: $pkg"
        return 0
    fi
    
    echo -e "${YELLOW}Attempting to install '$pkg'...${NC}"
    
    if check_command "apt-get"; then
        sudo apt-get update && sudo apt-get install -y "$pkg"
    elif check_command "dnf"; then
        sudo dnf install -y "$pkg"
    elif check_command "yum"; then
        sudo yum install -y "$pkg"
    elif check_command "pacman"; then
        sudo pacman -S --noconfirm "$pkg"
    elif check_command "zypper"; then
        sudo zypper install -y "$pkg"
    else
        echo -e "${RED}Error: No supported package manager found (apt, dnf, yum, pacman, zypper).${NC}"
        return 1
    fi
}

# Require a dependency, attempting to install if missing
# Usage: require_dependency "command" "package_name"
# If package_name is omitted, assumes it matches the command name
require_dependency() {
    local cmd="$1"
    local pkg="${2:-$cmd}"
    
    if check_command "$cmd"; then
        return 0
    fi
    
    echo -e "${YELLOW}Dependency '$cmd' not found.${NC}"
    read -p "Do you want to try to install '$pkg' now? [Y/n] " choice
    case "${choice:-Y}" in
        y|Y)
            if install_package "$pkg"; then
                if check_command "$cmd"; then
                    print_success "Successfully installed '$pkg'."
                    return 0
                fi
            fi
            print_error "Failed to install '$pkg'. Please install manually."
            return 1
            ;;
        *)
            print_error "Dependency '$cmd' is required to run this test."
            return 1
            ;;
    esac
}

# ===========================================
# Output Formatting
# ===========================================

# Print section header
print_header() {
    local title="$1"
    if [ "$QUIET" != true ]; then
        echo -e "\n${BLUE}=== $title ===${NC}\n"
    fi
}

# Print success message
print_success() {
    if [ "$QUIET" != true ]; then
        echo -e "${GREEN}✓ $1${NC}"
    fi
}

# Print error message
print_error() {
    echo -e "${RED}✗ $1${NC}" >&2
}

# Print warning message
print_warning() {
    if [ "$QUIET" != true ]; then
        echo -e "${YELLOW}! $1${NC}"
    fi
}

# Print info message (only in verbose mode)
print_info() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}ℹ $1${NC}"
    fi
}
