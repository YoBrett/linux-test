# Linux Test

Shell scripts for running OS tests on Linux Based Systems.

## Purpose

A collection of test scripts to validate, benchmark, and stress-test Linux processors and the operating systems running on them.

## Test Categories

- [x] **Gather Configuration** — Run `sudo dmidecode -t bios`
- [x] **CPU** — Performance benchmarks, stress tests
- [x] **Memory** — Allocation, bandwidth, stability
- [x] **Storage** — I/O throughput, latency
- [x] **Network** — Bandwidth, latency tests
- [x] **Thermal** — Temperature monitoring under load
- [x] **System Monitor** — SAR integration for activity logging
- [ ] **Compatibility** — Software/driver compatibility checks

## Scripts

| Script | Description |
|--------|-------------|
| `linux-test-suite.sh` | Master script with dialog menu |
| `lib/common.sh` | Shared functions, validation, utilities |
| `tests/cpu-benchmark.sh` | Sysbench, 7-zip, OpenSSL benchmarks |
| `tests/memory-test.sh` | Bandwidth (mbw) and stability (memtester) |
| `tests/storage-test.sh` | I/O performance (fio) |
| `tests/network-test.sh` | Bandwidth (iperf3), latency (ping), speedtest |
| `tests/stress-test.sh` | Load generation (stress-ng) |
| `tests/thermal-monitor.sh` | Temperature monitoring |
| `tests/gather-config.sh` | Hardware info gathering |

## Features (v1.2.0)

- **Interactive Menus**: Dialog-based or text fallback
- **Progress Indicators**: Spinner in text mode, infobox in dialog mode
- **Skip Tests**: Ctrl+C to cancel current test
- **SAR Integration**: System activity recording during tests
- **Input Validation**: Path sanitization, numeric validation
- **Dry Run Mode**: Preview commands without execution
- **Verbose/Quiet Modes**: Control output verbosity
- **Checksum Generation**: SHA256 for packages
- **Sudo Handling**: Toggle privileged commands on/off

## Security Improvements (v1.2.0)

- Input validation for all user-provided values
- Path sanitization to prevent command injection
- Safe temp file creation with mktemp
- Graceful sudo handling with fallback options

## Notes

- **Disclaimer:** Use Not Intended For Benchmarking Purposes.
- Renamed from "Ampere Test Suite" to "Linux Test Suite" in v1.1.0.
- Major security and UX improvements in v1.2.0.

---

Updated: 2026-02-23
