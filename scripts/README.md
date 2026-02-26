# Linux Test Suite

A collection of shell scripts for running OS tests on Linux Based Systems.

## License & Info

```text
######################################################################################
## PROGRAM   : Linux Test Suite
## PROGRAMER : Brett Collingwood
## EMAIL-1   : brett@amperecomputing.com 
## EMAIL-2   : brett.a.collingwood@gmail.com
## MUSE      : Kit 
## VERSION   : 1.0.0
## DATE      : 2026-02-25 
## PURPOSE   : Build a wrapper for a bunch of linux scripts to test a given platform 
## #---------------------------------------------------------------------------------#
## THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, 
## INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A 
## PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT 
## HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION 
## OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE 
## SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
######################################################################################
```

## Quick Start

```bash
# Run the interactive menu
./linux-test-suite.sh

# Or force text menu (no dialog required)
./linux-test-suite.sh --text

# Run all tests with defaults
./linux-test-suite.sh --run-all

# Create downloadable package
./linux-test-suite.sh --package
```

## Command Line Options

| Option | Description |
|--------|-------------|
| `--help, -h` | Show help message |
| `--version, -v` | Show version |
| `--text` | Force text menu (no dialog) |
| `--check-deps` | Check and install dependencies |
| `--run-all` | Run all tests with default settings |
| `--list-tests` | List available tests |
| `--package` | Create tar.gz package |
| `--verbose` | Enable verbose output |
| `--quiet` | Suppress non-essential output |
| `--dry-run` | Show what would be done without executing |

## Requirements

- bash 4.0+
- dialog or whiptail (for enhanced menus)
- stress-ng, sysbench, fio, iperf3, etc. (dependencies checked by script)

Install base dependencies:
```bash
# Debian/Ubuntu
sudo apt install dialog sysstat dmidecode stress-ng sysbench fio

# RHEL/CentOS
sudo dnf install dialog sysstat dmidecode stress-ng sysbench fio
```

## Structure

```
scripts/
├── linux-test-suite.sh     # Master script with menu
├── README.md
├── lib/
│   └── common.sh           # Shared functions & utilities
├── tests/
│   ├── stress-test.sh      # CPU/Memory stress (stress-ng)
│   ├── cpu-benchmark.sh    # CPU benchmarks
│   ├── memory-test.sh      # Memory tests
│   ├── storage-test.sh     # I/O tests
│   ├── network-test.sh     # Network tests
│   ├── gather-config.sh    # Hardware info
│   └── thermal-monitor.sh  # Thermal monitoring
└── results/                # Test results (auto-created)
```

## Available Tests

| Test | Description | Tools Used |
|------|-------------|------------|
| Gather Config | System hardware information | dmidecode, lscpu, lsblk |
| Stress Test | CPU/Memory stress testing | stress-ng |
| CPU Benchmark | CPU performance benchmarks | sysbench, 7zip, openssl |
| Memory Test | Memory bandwidth & stability | sysbench, memtester, mbw |
| Storage Test | I/O performance tests | fio |
| Network Test | Network bandwidth & latency | iperf3, speedtest-cli, ping |
| Thermal Monitor | Temperature monitoring | sysfs, lm-sensors |

## Test Results

- Each test creates a timestamped results file in `results/`
- Format: `{test_name}_{YYYYMMDD_HHMMSS}.txt`
- Includes system info, timestamps, and test output
- System activity report (SAR) generated on exit

## Running Individual Tests

```bash
# Configure and run via menu
./tests/stress-test.sh

# Run with defaults
./tests/stress-test.sh --run

# Gather config without sudo
./tests/gather-config.sh --no-sudo
```

## Packaging

Create a distributable tar.gz:
```bash
./linux-test-suite.sh --package
# Creates: linux-test-suite_YYYYMMDD_HHMMSS.tar.gz
# Also creates: linux-test-suite_YYYYMMDD_HHMMSS.tar.gz.sha256
```

## Skipping Tests

Press **Ctrl+C** during any test to skip it and return to the menu.

## Troubleshooting

### "Permission denied" errors
Some tests require root privileges (e.g., `dmidecode`). Either:
- Run with sudo: `sudo ./linux-test-suite.sh`
- Use the "Toggle privileged commands" option in Gather Config

### Missing dependencies
Run the dependency check from the menu or:
```bash
./linux-test-suite.sh --check-deps
```

### Dialog not working
Force text mode:
```bash
./linux-test-suite.sh --text
```

### Tests taking too long
Press **Ctrl+C** to skip the current test and continue.

## Example Output

```
======================================================================
                            Stress Test
       *** Use Not Intended For Benchmarking Purposes ***
======================================================================

Host:       linux-server
CPU:        Neoverse-N1
Cores:      80
Memory:     125Gi
Kernel:     6.17.0-14-generic
Arch:       aarch64

START TIME: 2026-02-23 15:00:00 PST
==============================================

Configuration:
  CPU Workers:    80
  Memory Workers: 2
  Memory Size:    1G
  Duration:       60s

[Test output here...]

==============================================
END TIME:   2026-02-23 15:01:00 PST
STATUS:     COMPLETED
==============================================
```

## Security Notes

- User inputs are validated and sanitized
- Paths are checked for dangerous characters
- Sudo commands can be disabled if not needed
- Temp files use secure creation (mktemp)

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## Changelog

### v1.0.0 (2026-02-25)
- Initial release — Linux Test Suite
- Interactive dialog and text menus
- Progress indicators
- Input validation and sanitization
- `--verbose`, `--quiet`, `--dry-run`, `--list-tests` flags
- SHA256 checksum generation for packages
- Graceful sudo handling (toggle option)
- SAR system monitoring integration
- Ctrl+C to skip tests
- Comprehensive error handling
- SAR report flushed before packaging

---

Version 1.0.0 | Created for Linux testing
