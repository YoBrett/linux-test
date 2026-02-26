#!/bin/bash
######################################################################################
## PROGRAM   : storage-test.sh
## PROGRAMER : Brett Collingwood
## MUSE      : Kit
## VERSION   : 1.2.0
## DATE      : 2026-02-23
## PURPOSE   : Storage I/O performance tests (FIO)
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
TEST_PATH="/tmp/linux-fio-test"
BLOCK_SIZE="4k"
FILE_SIZE="1G"
RUNTIME=30
IODEPTH=16
NUMJOBS=4
TEST_TYPE="all"

# Check for dialog
USE_DIALOG=false
if command -v dialog &> /dev/null; then
    USE_DIALOG=true
fi

# Validate and set test path
set_test_path() {
    local new_path="$1"
    
    # Check for dangerous characters (command injection prevention)
    if ! validate_safe_path "$new_path"; then
        print_error "Invalid path: contains dangerous characters"
        return 1
    fi
    
    # Sanitize the path
    new_path=$(sanitize_string "$new_path")
    
    # Check if path exists or can be created
    if [ -d "$new_path" ]; then
        if [ -w "$new_path" ]; then
            TEST_PATH="$new_path"
            return 0
        else
            print_error "Path exists but is not writable: $new_path"
            return 1
        fi
    else
        # Try to create the directory
        if mkdir -p "$new_path" 2>/dev/null; then
            TEST_PATH="$new_path"
            return 0
        else
            print_error "Cannot create directory: $new_path"
            return 1
        fi
    fi
}

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
        cmd=(dialog --clear --backtitle "Linux Test Suite - Storage Test" \
            --title "Storage Test Configuration (fio)" \
            --menu "Current Settings:\n\n1) Test Path:   $TEST_PATH\n2) Block Size:  $BLOCK_SIZE\n3) File Size:   $FILE_SIZE\n4) Runtime:     ${RUNTIME}s\n5) IO Depth:    $IODEPTH\n6) Num Jobs:    $NUMJOBS\n7) Test Type:   $TEST_TYPE\n\nSelect option to change or run:" 22 65 9)
        
        options=(
            1 "Test Path (directory)"
            2 "Block Size (4k, 64k, 1M, etc.)"
            3 "File Size (e.g., 1G, 4G)"
            4 "Runtime (seconds)"
            5 "IO Depth"
            6 "Number of Jobs"
            7 "Test Type (read/write/mixed)"
            R "Run test with current settings"
            Q "Return to main menu"
        )
        
        choice=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
        
        case $choice in
            1)
                val=$(dialog --clear --backtitle "Linux Test Suite - Storage Test" \
                    --title "Test Path" \
                    --inputbox "Enter test path:" 8 50 "$TEST_PATH" \
                    2>&1 >/dev/tty)
                if [[ -n "$val" ]]; then
                    if ! set_test_path "$val"; then
                        dialog --msgbox "Invalid or inaccessible path. Please try again." 6 50
                    fi
                fi
                ;;
            2)
                val=$(dialog --clear --backtitle "Linux Test Suite - Storage Test" \
                    --title "Block Size" \
                    --inputbox "Enter block size:" 8 40 "$BLOCK_SIZE" \
                    2>&1 >/dev/tty)
                if [[ -n "$val" ]] && validate_size_string "$val"; then
                    BLOCK_SIZE=$val
                fi
                ;;
            3)
                val=$(dialog --clear --backtitle "Linux Test Suite - Storage Test" \
                    --title "File Size" \
                    --inputbox "Enter file size:" 8 40 "$FILE_SIZE" \
                    2>&1 >/dev/tty)
                if [[ -n "$val" ]] && validate_size_string "$val"; then
                    FILE_SIZE=$val
                fi
                ;;
            4)
                val=$(dialog --clear --backtitle "Linux Test Suite - Storage Test" \
                    --title "Runtime" \
                    --inputbox "Enter runtime in seconds:" 8 40 "$RUNTIME" \
                    2>&1 >/dev/tty)
                [[ "$val" =~ ^[0-9]+$ ]] && RUNTIME=$val
                ;;
            5)
                val=$(dialog --clear --backtitle "Linux Test Suite - Storage Test" \
                    --title "IO Depth" \
                    --inputbox "Enter IO depth:" 8 40 "$IODEPTH" \
                    2>&1 >/dev/tty)
                [[ "$val" =~ ^[0-9]+$ ]] && IODEPTH=$val
                ;;
            6)
                val=$(dialog --clear --backtitle "Linux Test Suite - Storage Test" \
                    --title "Number of Jobs" \
                    --inputbox "Enter number of jobs:" 8 40 "$NUMJOBS" \
                    2>&1 >/dev/tty)
                [[ "$val" =~ ^[0-9]+$ ]] && NUMJOBS=$val
                ;;
            7)
                tt=$(dialog --clear --backtitle "Linux Test Suite - Storage Test" \
                    --title "Select Test Type" \
                    --menu "Choose storage test type:" 15 50 6 \
                    all "Run all tests" \
                    read "Sequential read" \
                    write "Sequential write" \
                    randread "Random read" \
                    randwrite "Random write" \
                    mixed "Mixed 70/30 read/write" \
                    2>&1 >/dev/tty)
                [[ -n "$tt" ]] && TEST_TYPE=$tt
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
        echo "  Storage Test Configuration (fio)"
        echo "=============================================="
        echo ""
        echo "Current Settings:"
        echo "  1) Test Path:   $TEST_PATH"
        echo "  2) Block Size:  $BLOCK_SIZE"
        echo "  3) File Size:   $FILE_SIZE"
        echo "  4) Runtime:     ${RUNTIME}s"
        echo "  5) IO Depth:    $IODEPTH"
        echo "  6) Num Jobs:    $NUMJOBS"
        echo "  7) Test Type:   $TEST_TYPE"
        echo ""
        echo "Test types:"
        echo "     all       - Run all tests"
        echo "     read      - Sequential read"
        echo "     write     - Sequential write"
        echo "     randread  - Random read"
        echo "     randwrite - Random write"
        echo "     mixed     - Mixed 70/30 read/write"
        echo ""
        echo "  r) Run test with current settings"
        echo "  q) Return to main menu"
        echo ""
        echo "              *** Use Not Intended For Benchmarking Purposes ***"
        echo ""
        read -p "Select option: " choice
        
        case $choice in
            1)
                read -p "Enter test path: " val
                if [[ -n "$val" ]]; then
                    if ! set_test_path "$val"; then
                        echo "Invalid or inaccessible path. Press Enter to continue..."
                        read
                    fi
                fi
                ;;
            2)
                read -p "Enter block size (4k, 64k, 1M): " val
                if [[ -n "$val" ]] && validate_size_string "$val"; then
                    BLOCK_SIZE=$val
                else
                    echo "Invalid size format. Press Enter to continue..."
                    read
                fi
                ;;
            3)
                read -p "Enter file size (e.g., 1G, 4G): " val
                if [[ -n "$val" ]] && validate_size_string "$val"; then
                    FILE_SIZE=$val
                else
                    echo "Invalid size format. Press Enter to continue..."
                    read
                fi
                ;;
            4)
                read -p "Enter runtime in seconds: " val
                if validate_positive_int "$val"; then
                    RUNTIME=$val
                else
                    echo "Invalid number. Press Enter to continue..."
                    read
                fi
                ;;
            5)
                read -p "Enter IO depth: " val
                if validate_positive_int "$val"; then
                    IODEPTH=$val
                else
                    echo "Invalid number. Press Enter to continue..."
                    read
                fi
                ;;
            6)
                read -p "Enter number of jobs: " val
                if validate_positive_int "$val"; then
                    NUMJOBS=$val
                else
                    echo "Invalid number. Press Enter to continue..."
                    read
                fi
                ;;
            7)
                read -p "Enter test type (all/read/write/randread/randwrite/mixed): " val
                case "$val" in
                    all|read|write|randread|randwrite|mixed)
                        TEST_TYPE=$val
                        ;;
                    *)
                        echo "Invalid test type. Press Enter to continue..."
                        read
                        ;;
                esac
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

# Run a single fio test
run_fio_test() {
    local test_name="$1"
    local rw_type="$2"
    local result_file="$3"
    local extra_opts="${4:-}"
    
    print_header "FIO: $test_name"
    
    {
        echo "--- $test_name ---"
        echo "RW Type: $rw_type"
        echo ""
    } >> "$result_file"
    
    # Use quoted variables to prevent injection
    local fio_cmd="fio --name=\"$test_name\" \
        --directory=\"$TEST_PATH\" \
        --ioengine=libaio \
        --direct=1 \
        --rw=$rw_type \
        --bs=$BLOCK_SIZE \
        --size=$FILE_SIZE \
        --runtime=$RUNTIME \
        --time_based \
        --iodepth=$IODEPTH \
        --numjobs=$NUMJOBS \
        --group_reporting \
        --output-format=normal \
        $extra_opts"
    
    echo "Running: $test_name (${RUNTIME}s)..."
    log_verbose "Command: $fio_cmd"
    run_with_progress "$fio_cmd" "$result_file"
    
    local exit_code=$?
    echo "" >> "$result_file"
    
    return $exit_code
}

# Sequential read test
run_seq_read() {
    run_fio_test "Sequential_Read" "read" "$1"
}

# Sequential write test
run_seq_write() {
    run_fio_test "Sequential_Write" "write" "$1"
}

# Random read test
run_rand_read() {
    run_fio_test "Random_Read" "randread" "$1"
}

# Random write test
run_rand_write() {
    run_fio_test "Random_Write" "randwrite" "$1"
}

# Mixed read/write test (70/30)
run_mixed() {
    run_fio_test "Mixed_RW_70_30" "randrw" "$1" "--rwmixread=70"
}

run_test() {
    print_header "Storage Test (fio)"
    
    # Check for fio
    if ! require_dependency "fio"; then
        return 1
    fi
    
    # Validate and create test directory
    if ! set_test_path "$TEST_PATH"; then
        print_error "Cannot use test path: $TEST_PATH"
        return 1
    fi
    
    local result_file=$(start_test "Storage Test")
    print_success "Results will be saved to: $result_file"
    
    {
        echo "Configuration:"
        echo "  Test Path:   $TEST_PATH"
        echo "  Block Size:  $BLOCK_SIZE"
        echo "  File Size:   $FILE_SIZE"
        echo "  Runtime:     ${RUNTIME}s"
        echo "  IO Depth:    $IODEPTH"
        echo "  Num Jobs:    $NUMJOBS"
        echo "  Test Type:   $TEST_TYPE"
        echo ""
        echo "Filesystem Info:"
        df -h "$TEST_PATH" 2>/dev/null | head -2
        echo ""
    } >> "$result_file"
    
    local exit_code=0
    
    case "$TEST_TYPE" in
        all)
            run_seq_read "$result_file" || exit_code=1
            run_seq_write "$result_file" || exit_code=1
            run_rand_read "$result_file" || exit_code=1
            run_rand_write "$result_file" || exit_code=1
            run_mixed "$result_file" || exit_code=1
            ;;
        read)
            run_seq_read "$result_file" || exit_code=1
            ;;
        write)
            run_seq_write "$result_file" || exit_code=1
            ;;
        randread)
            run_rand_read "$result_file" || exit_code=1
            ;;
        randwrite)
            run_rand_write "$result_file" || exit_code=1
            ;;
        mixed)
            run_mixed "$result_file" || exit_code=1
            ;;
        *)
            print_error "Unknown test type: $TEST_TYPE"
            echo "Unknown test type: $TEST_TYPE" >> "$result_file"
            exit_code=1
            ;;
    esac
    
    # Cleanup test files
    print_header "Cleanup"
    echo "Removing test files from $TEST_PATH..."
    rm -f "$TEST_PATH"/*.0.*
    rm -f "$TEST_PATH"/Sequential_* "$TEST_PATH"/Random_* "$TEST_PATH"/Mixed_*
    print_success "Cleanup complete"
    
    {
        echo ""
        echo "Cleanup: Test files removed"
    } >> "$result_file"
    
    end_test "$result_file" $exit_code
    
    if [ $exit_code -eq 0 ]; then
        print_success "Storage test completed successfully"
    else
        print_warning "Storage test completed with some errors"
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
