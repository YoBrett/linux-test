# README1ST.md - Decryption & Installation Instructions

## 1. Verify Integrity
Verify the downloaded archive against the SHA256 checksum:

```bash
sha256sum -c __BUILD_FILENAME__.tar.gz.gpg.sha256
```

## 2. Decrypt the Archive
```bash
gpg -d -o __BUILD_FILENAME__.tar.gz __BUILD_FILENAME__.tar.gz.gpg
```
*(Enter the password when prompted.)*

## 3. Extract & Run
```bash
tar -xzf __BUILD_FILENAME__.tar.gz
sudo ./scripts/linux-test-suite.sh
```