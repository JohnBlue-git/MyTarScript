# My Tar Package Script

A flexible bash script wrapper for `tar` that simplifies archive creation and extraction with support for multiple compression formats, selective file handling, and skip lists.

## Features

- 🗜️ **Multiple Compression Formats**: Support for GZIP, BZIP2, XZ, and LZIP
- 📋 **Selective Archiving**: Include only specific files/directories using a package list
- 🚫 **Skip List**: Exclude files/directories from archiving
- 📁 **Custom Working Directory**: Specify source/destination directories
- ✅ **Validation**: Comprehensive error checking and validation
- 🎨 **Colored Output**: User-friendly colored console output
- 🧪 **Well-Tested**: Comprehensive pytest test suite

## Table of Contents

- [Installation](#installation)
- [Usage](#usage)
- [Examples](#examples)
- [Configuration Files](#configuration-files)
- [Testing](#testing)
- [Requirements](#requirements)
- [Basic Tar Usage Reference](#basic-tar-usage-reference)

## Installation

1. Clone or download this repository:
```bash
git clone https://github.com/JohnBlue-git/MyTarPackageScript.git
cd MyTarPackageScript
```

2. Make the script executable:
```bash
chmod +x my_tar.sh
```

3. (Optional) Add to your PATH for system-wide access:
```bash
sudo ln -s $(pwd)/my_tar.sh /usr/local/bin/my_tar
```

## Usage

### Basic Syntax

```bash
./my_tar.sh [OPTIONS] <archive.tar>
```

### Command-Line Options

| Option | Description | Required | Default |
|--------|-------------|----------|---------|
| `--mode=MODE` | Operation mode: `create` or `extract` | ✅ Yes | - |
| `--dir=PATH` | Working directory for source/destination | ❌ No | Current directory |
| `--comp=TYPE` | Compression type: `GZ`, `BZ2`, `XZ`, or `LZ` | ❌ No | None |
| `--select=FILE` | Text file with list of files/dirs to include | ❌ No | All files |
| `--skip=FILE` | Text file with list of files/dirs to exclude | ❌ No | None |
| `--help` | Display help message | ❌ No | - |

### Compression Types

| Type | Extension | Description | Speed | Ratio |
|------|-----------|-------------|-------|-------|
| `GZ` | `.tar.gz` | GZIP compression | Fast | Good |
| `BZ2` | `.tar.bz2` | BZIP2 compression | Medium | Better |
| `XZ` | `.tar.xz` | XZ compression | Slow | Best |
| `LZ` | `.tar.lz` | LZIP compression | Medium | Very Good |

## Examples

### 1. Create a Simple Archive

Create an uncompressed tar archive of the current directory:

```bash
./my_tar.sh --mode=create archive.tar
```

### 2. Create with Compression

Create a GZIP compressed archive:

```bash
./my_tar.sh --mode=create --comp=GZ archive.tar.gz
# Output: archive.tar.gz
```

Create with BZIP2 compression:

```bash
./my_tar.sh --mode=create --comp=BZ2 archive.tar.bz2
# Output: archive.tar.bz2
```

### 3. Extract Archives

Extract an uncompressed archive:

```bash
./my_tar.sh --mode=extract archive.tar
```

Extract a compressed archive:

```bash
./my_tar.sh --mode=extract archive.tar.gz
```

Extract to a specific directory:

```bash
./my_tar.sh --dir=/path/to/destination --mode=extract archive.tar.gz
```

### 4. Selective Archiving with Package List

Create `package_list.txt`:
```text
default
develop
release
default.xml
develop.xml
release.xml
```

Create archive with only selected files:

```bash
./my_tar.sh --mode=create --comp=GZ --select=package_list.txt archive.tar.gz
```

### 5. Exclude Files with Skip List

Create `skip_list.txt`:
```text
non_existed.xml
non_existed
*.log
temp/
```

Create archive excluding specified files:

```bash
./my_tar.sh --mode=create --comp=GZ --skip=skip_list.txt archive.tar.gz
```

### 6. Combine Select and Skip Lists

Archive only selected files but exclude specific ones:

```bash
./my_tar.sh --mode=create --comp=XZ \
    --select=package_list.txt \
    --skip=skip_list.txt \
    archive.tar
```

### 7. Custom Working Directory

Archive from a specific directory:

```bash
./my_tar.sh --dir=/path/to/source --mode=create --comp=GZ archive.tar.gz
```

Extract to a specific directory:

```bash
./my_tar.sh --dir=/path/to/destination --mode=extract archive.tar.gz
```

### 8. Complete Example

```bash
# Create a compressed archive from /data/project
# Include only files listed in package_list.txt
# Exclude files listed in skip_list.txt
./my_tar.sh \
    --dir=/data/project \
    --mode=create \
    --comp=XZ \
    --select=package_list.txt \
    --skip=skip_list.txt \
    backup_2026.tar.xz
```

## Configuration Files

### Package List Format

The package list file (`--select`) contains file and directory names to include, one per line:

```text
# Files
default.xml
develop.xml
release.xml

# Directories
default
develop
release

# Patterns (if your implementation supports wildcards)
*.conf
config/
```

### Skip List Format

The skip list file (`--skip`) contains file and directory names to exclude, one per line:

```text
# Specific files
debug.log
temp.txt

# Directories
temp/
cache/
node_modules/

# Patterns
*.tmp
*.bak
.git/
```

### Notes on List Files

- Lines starting with `#` are treated as comments (if your script supports it)
- Empty lines are ignored
- File/directory names are relative to the working directory
- Non-existent files in skip list are safely ignored

## Testing

This project includes a comprehensive pytest test suite to ensure reliability.

### Setup Testing Environment

1. Install Python 3 (if not already installed)
2. Install test dependencies:

```bash
pip install -r requirements-test.txt
```

Or install manually:

```bash
pip install pytest pytest-cov pytest-xdist
```

### Running Tests

#### Quick Start with run_tests.sh

The easiest way to run tests is using the provided test runner script:

```bash
# Make it executable first (one time only)
chmod +x run_tests.sh

# Run tests
./run_tests.sh
```

This script will:
- ✅ Check if pytest is installed
- 📦 Automatically install test dependencies if needed (from `requirements-test.txt`)
- 🔧 Make `my_tar.sh` executable if needed
- 🧪 Run all tests with verbose output
- ✨ Display colored, formatted results
- 📊 Show pass/fail summary

**Example output:**
```
======================================
My Tar Package Script - Test Runner
======================================

🧪 Running tests...

tests/test_my_tar.py::TestMyTar::test_script_exists PASSED
tests/test_my_tar.py::TestMyTar::test_create_simple_archive PASSED
...
18 passed in 0.67s

✅ All tests passed!
```

#### Manual Test Execution

Run all tests:

```bash
pytest
```

Run with verbose output:

```bash
pytest -v
```

Run with coverage report:

```bash
pytest --cov=. --cov-report=html --cov-report=term
```

Run specific test:

```bash
pytest tests/test_my_tar.py::TestMyTar::test_create_simple_archive -v
```

Run tests in parallel (faster):

```bash
pytest -n auto
```

### Test Coverage

The test suite covers:

- ✅ Archive creation (compressed and uncompressed)
- ✅ Archive extraction (compressed and uncompressed)
- ✅ All compression formats (GZ, BZ2, XZ, LZ)
- ✅ Selective file inclusion with `--select`
- ✅ File exclusion with `--skip`
- ✅ Combined select and skip lists
- ✅ Custom working directories with `--dir` parameter
- ✅ Error handling (invalid parameters, missing files)
- ✅ Edge cases (empty lists, non-existent files)

**Note:** Tests use the existing `./files/` directory structure to ensure real-world functionality. The directory contains:
- `default/`, `develop/`, `release/` directories
- `default.xml`, `develop.xml`, `release.xml` files
- Matches the structure defined in `package_list.txt`

## Requirements

### System Requirements

- **Bash**: Version 4.0 or higher
- **tar**: GNU tar (usually pre-installed on Linux)
- **Compression Tools** (optional, for compression support):
  - `gzip` - for GZ compression
  - `bzip2` - for BZ2 compression
  - `xz` - for XZ compression
  - `lzip` - for LZ compression

### Install Compression Tools

On Ubuntu/Debian:
```bash
sudo apt-get install gzip bzip2 xz-utils lzip
```

On CentOS/RHEL:
```bash
sudo yum install gzip bzip2 xz lzip
```

On macOS:
```bash
brew install gzip bzip2 xz lzip
```

### Python Requirements (for testing)

- Python 3.7 or higher
- pytest >= 7.0.0
- pytest-cov >= 4.0.0 (optional, for coverage)
- pytest-xdist >= 3.0.0 (optional, for parallel testing)

## Basic Tar Usage Reference

This section provides a quick reference for native `tar` commands. The `my_tar.sh` script wraps these commands to provide a simpler, more consistent interface.

### Basic Archive Operations

#### Uncompressed Tar

```bash
# Create archive
tar -cpvf archive.tar file1 file2 directory/

# Extract archive
tar -xpvf archive.tar
```

**Flags:**
- `-c` = create archive
- `-x` = extract archive
- `-p` = preserve permissions
- `-v` = verbose output
- `-f` = specify filename

### Compressed Archives

#### Gzip Compression (.tar.gz)

```bash
# Create compressed archive
tar -cpzvf archive.tar.gz file1 file2 directory/

# Extract compressed archive
tar -xpzvf archive.tar.gz
```

**Additional flag:** `-z` = gzip compression

#### Bzip2 Compression (.tar.bz2)

```bash
# Create compressed archive
tar -cpjvf archive.tar.bz2 file1 file2 directory/

# Extract compressed archive
tar -xpjvf archive.tar.bz2
```

**Additional flag:** `-j` = bzip2 compression

#### XZ Compression (.tar.xz)

```bash
# Create compressed archive
tar -cpJvf archive.tar.xz file1 file2 directory/

# Extract compressed archive
tar -xpJvf archive.tar.xz
```

**Additional flag:** `-J` = xz compression

#### Lzip Compression (.tar.lz)

```bash
# Create compressed archive
tar -cpvf --lzip archive.tar.lz file1 file2 directory/

# Extract compressed archive
tar -xpvf --lzip archive.tar.lz
```

**Additional flag:** `--lzip` = lzip compression

### Working with Directories

Specify source and destination directories:

```bash
# Create archive from specific directory
tar -C /source/directory -cpvf backup.tar project/ report.txt

# Extract to specific directory
tar -C /output/directory -xpvf archive.tar
```

**Additional flag:** `-C` = change to directory

### Selective File Inclusion

Include only files listed in a text file:

```bash
# Create archive with file list
tar -cpvf archive.tar -T package_list.txt --ignore-failed-read
```

**Additional flags:**
- `-T` = read file list from file
- `--ignore-failed-read` = continue if files don't exist

**Example package_list.txt:**
```text
default
develop
release
default.xml
develop.xml
release.xml
```

### Excluding Files

Exclude specific files or patterns:

```bash
# Exclude single file
tar -cpvf archive.tar --exclude='non_existed.xml' .

# Exclude multiple files
tar -cpvf archive.tar --exclude='non_existed.xml' --exclude='non_existed' .

# Exclude using brace expansion (bash)
tar -cpvf archive.tar --exclude={'non_existed.xml','non_existed'} .

# Exclude patterns
tar -cpvf archive.tar --exclude='*.log' --exclude='temp/*' .
```

**Additional flag:** `--exclude=PATTERN` = exclude files matching pattern

### My Tar Script vs Native Tar

The `my_tar.sh` script provides several advantages over native tar:

| Feature | Native Tar | my_tar.sh |
|---------|------------|-----------|
| Compression auto-detection | Manual flags | Automatic from extension |
| Skip list file | Multiple `--exclude` | Single `--skip=file.txt` |
| Select list file | `-T` with specific syntax | Simple `--select=file.txt` |
| Working directory | `-C` flag (can be confusing) | Clear `--dir=PATH` |
| Error handling | Basic | Comprehensive validation |
| User feedback | Minimal | Colored, informative output |

**Example comparison:**

Native tar:
```bash
cd /source/directory
tar -cpzvf /output/archive.tar.gz -T package_list.txt --exclude='debug.log' .
```

my_tar.sh:
```bash
./my_tar.sh --dir=/source/directory --mode=create --comp=GZ \
    --select=package_list.txt --skip=skip_list.txt \
    /output/archive.tar
```

### Common Tar Options

| Option | Description |
|--------|-------------|
| `-c` | Create a new archive |
| `-x` | Extract files from archive |
| `-t` | List archive contents |
| `-v` | Verbose output |
| `-f FILE` | Use archive file |
| `-p` | Preserve permissions |
| `-z` | Gzip compression |
| `-j` | Bzip2 compression |
| `-J` | XZ compression |
| `--lzip` | Lzip compression |
| `-C DIR` | Change to directory |
| `-T FILE` | Get names to extract/create from file |
| `--exclude=PATTERN` | Exclude files matching pattern |
| `--ignore-failed-read` | Don't exit on unreadable files |

## Project Structure

```
MyTarPackageScript/
├── my_tar.sh              # Main script
├── package_list.txt       # Example package list
├── skip_list.txt          # Example skip list
├── README.md              # This file
├── requirements-test.txt  # Test dependencies
├── pytest.ini             # Pytest configuration
├── files/                 # Example files directory
│   ├── default.xml
│   ├── develop.xml
│   ├── release.xml
│   ├── default/
│   ├── develop/
│   └── release/
└── tests/                 # Test suite
    ├── conftest.py        # Pytest configuration
    └── test_my_tar.py     # Main test file
```

## Acknowledgments

- Built on top of GNU `tar`
- Inspired by common backup and archiving needs
- Test suite powered by pytest
