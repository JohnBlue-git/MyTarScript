#!/bin/bash

# Script: my_tar.sh
# Description: Archive/Extract files using tar with compression options and selective file handling
# Usage: my_tar.sh [--dir=PATH] <archive.tar> --mode=create|extract [--comp=GZ|BZ2|XZ|LZ] [--select=<package_list.txt>] [--skip=<skip_list.txt>]

set -euo pipefail  # Exit on errors, unset variables, and pipeline failures

# Default values
WORKING_DIR="."
ARCHIVE=""
MODE=""
COMPRESSION=""
SELECT_FILE=""
SKIP_FILE=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS] <archive.tar>

OPTIONS:
    --dir=PATH              Working directory (default: current directory)
    --mode=create|extract   Mode of operation (required)
    --comp=GZ|BZ2|XZ|LZ    Compression type (optional)
                           GZ  - gzip compression (.tar.gz)
                           BZ2 - bzip2 compression (.tar.bz2)
                           XZ  - xz compression (.tar.xz)
                           LZ  - lzip compression (.tar.lz)
    --select=FILE          Text file containing list of files/dirs to include
    --skip=FILE            Text file containing list of files/dirs to exclude

EXAMPLES:
    # Create archive with gzip compression
    $0 --mode=create --comp=GZ archive.tar

    # Extract archive
    $0 --mode=extract archive.tar.gz

    # Create with selective files
    $0 --dir=/path/to/source --mode=create --comp=GZ archive.tar --select=package_list.txt

    # Create with skip list
    $0 --mode=create --comp=BZ2 archive.tar --skip=skip_list.txt

    # Create with both select and skip
    $0 --mode=create --comp=XZ archive.tar --select=package_list.txt --skip=skip_list.txt

EOF
    exit 1
}

# Function to print error messages
error() {
    echo -e "${RED}ERROR: $1${NC}" >&2
    exit 1
}

# Function to print info messages
info() {
    echo -e "${GREEN}INFO: $1${NC}"
}

# Function to print warning messages
warn() {
    echo -e "${YELLOW}WARNING: $1${NC}"
}

# Temp file/dir tracking for guaranteed cleanup on all exit paths (success, error, signal)
TEMP_FILES=()
TEMP_DIRS=()

cleanup() {
    [[ ${#TEMP_FILES[@]} -gt 0 ]] && rm -f "${TEMP_FILES[@]}"
    [[ ${#TEMP_DIRS[@]} -gt 0 ]]  && rm -rf "${TEMP_DIRS[@]}"
}
trap cleanup EXIT

# Function to validate an archive entry path against traversal attacks
# Returns 0 if safe, 1 if unsafe
validate_entry() {
    local entry="$1"
    # Reject absolute paths (starting with /)
    if [[ "$entry" == /* ]]; then
        return 1
    fi
    # Reject any '..' path component (covers /../, ../, /.., and standalone ..)
    if [[ "$entry" =~ (^|/)\.\./(/|$) ]] || [[ "$entry" == ".." ]] || [[ "$entry" == "../"* ]] || [[ "$entry" == *"/.." ]]; then
        return 1
    fi
    # Reject Windows-style backslash path traversal (e.g., ..\ )
    if [[ "$entry" =~ \.\.\\ ]]; then
        return 1
    fi
    return 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dir=*)
            WORKING_DIR="${1#*=}"
            shift
            ;;
        --mode=*)
            MODE="${1#*=}"
            shift
            ;;
        --comp=*)
            COMPRESSION="${1#*=}"
            shift
            ;;
        --select=*)
            SELECT_FILE="${1#*=}"
            shift
            ;;
        --skip=*)
            SKIP_FILE="${1#*=}"
            shift
            ;;
        -h|--help)
            usage
            ;;
        -*)
            error "Unknown option: $1"
            ;;
        *)
            if [ -z "$ARCHIVE" ]; then
                ARCHIVE="$1"
            else
                error "Multiple archive names specified"
            fi
            shift
            ;;
    esac
done

# Validate required arguments
if [ -z "$ARCHIVE" ]; then
    error "Archive name is required"
fi

if [ -z "$MODE" ]; then
    error "--mode is required (create or extract)"
fi

# Validate mode
case "$MODE" in
    create|extract)
        ;;
    *)
        error "Invalid mode: $MODE. Must be 'create' or 'extract'"
        ;;
esac

# Validate compression type if specified
COMP_FLAG=""
ARCHIVE_EXT=""
if [ -n "$COMPRESSION" ]; then
    case "$COMPRESSION" in
        GZ)
            COMP_FLAG="-z"
            ARCHIVE_EXT=".gz"
            ;;
        BZ2)
            COMP_FLAG="-j"
            ARCHIVE_EXT=".bz2"
            ;;
        XZ)
            COMP_FLAG="-J"
            ARCHIVE_EXT=".xz"
            ;;
        LZ)
            COMP_FLAG="--lzip"
            ARCHIVE_EXT=".lz"
            ;;
        *)
            error "Invalid compression type: $COMPRESSION. Must be one of: GZ, BZ2, XZ, LZ"
            ;;
    esac
fi

# Validate working directory
if [ ! -d "$WORKING_DIR" ]; then
    error "Working directory does not exist: $WORKING_DIR"
fi

# Function to read and validate file list
read_file_list() {
    local file="$1"
    local list_name="$2"
    local items=()
    
    if [ ! -f "$file" ]; then
        error "$list_name file does not exist: $file"
    fi
    
    while IFS= read -r line || [ -n "$line" ]; do
        # Skip empty lines and comments
        line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [ -n "$line" ] && [[ ! "$line" =~ ^# ]]; then
            items+=("$line")
        fi
    done < "$file"
    
    if [ ${#items[@]} -eq 0 ]; then
        warn "$list_name file is empty or contains only comments: $file"
    fi
    
    printf '%s\n' "${items[@]}"
}

# Function to create archive
create_archive() {
    local tar_opts=("-c" "-v" "-f")
    [ -n "$COMP_FLAG" ] && tar_opts=("-c" "$COMP_FLAG" "-v" "-f")
    local archive_name="$ARCHIVE"
    local temp_list=""
    local final_list=""
    
    # Add compression extension if needed
    if [ -n "$ARCHIVE_EXT" ] && [[ ! "$archive_name" =~ \.(tar\.gz|tgz|tar\.bz2|tbz2|tar\.xz|txz|tar\.lz|tlz)$ ]]; then
        archive_name="${archive_name}${ARCHIVE_EXT}"
    fi
    
    info "Creating archive: $archive_name"
    info "Working directory: $WORKING_DIR"
    
    cd "$WORKING_DIR" || error "Cannot change to working directory: $WORKING_DIR"
    
    # Build list of files to archive
    if [ -n "$SELECT_FILE" ]; then
        info "Reading select file: $SELECT_FILE"
        temp_list=$(mktemp)
        TEMP_FILES+=("$temp_list")
        read_file_list "$SELECT_FILE" "Select" > "$temp_list"
        final_list="$temp_list"
    else
        # Use all files in current directory
        temp_list=$(mktemp)
        TEMP_FILES+=("$temp_list")
        find . -maxdepth 1 ! -path . | sed 's|^\./||' > "$temp_list"
        final_list="$temp_list"
    fi
    
    # Apply skip list if specified
    if [ -n "$SKIP_FILE" ]; then
        info "Reading skip file: $SKIP_FILE"
        local skip_temp=$(mktemp)
        TEMP_FILES+=("$skip_temp")
        read_file_list "$SKIP_FILE" "Skip" > "$skip_temp"
        
        # Filter out skipped items
        local filtered_list=$(mktemp)
        TEMP_FILES+=("$filtered_list")
        while IFS= read -r item; do
            local skip_item=0
            while IFS= read -r skip_pattern; do
                if [ "$item" = "$skip_pattern" ]; then
                    skip_item=1
                    warn "Skipping: $item"
                    break
                fi
            done < "$skip_temp"
            
            if [ $skip_item -eq 0 ]; then
                echo "$item" >> "$filtered_list"
            fi
        done < "$final_list"
        
        rm -f "$skip_temp"
        rm -f "$final_list"
        final_list="$filtered_list"
    fi
    
    # Check if we have any files to archive
    if [ ! -s "$final_list" ]; then
        rm -f "$final_list"
        error "No files to archive after applying filters"
    fi
    
    # Verify files exist and create archive
    info "Verifying files..."
    local missing_files=0
    while IFS= read -r item; do
        if [ ! -e "$item" ]; then
            warn "File/directory does not exist: $item"
            missing_files=$((missing_files + 1))
        fi
    done < "$final_list"
    
    # Create the archive using tar with file list
    info "Creating tar archive..."
    if [ "$COMPRESSION" = "LZ" ]; then
        tar cvf - -T "$final_list" --ignore-failed-read 2>/dev/null | lzip > "$archive_name"
    else
        tar "${tar_opts[@]}" "$archive_name" -T "$final_list" --ignore-failed-read 2>/dev/null
    fi
    
    # Cleanup
    rm -f "$final_list"
    
    if [ -f "$archive_name" ]; then
        local size=$(du -h "$archive_name" | cut -f1)
        info "Archive created successfully: $archive_name (Size: $size)"
    else
        error "Failed to create archive"
    fi
}

# Function to extract archive
extract_archive() {
    # Resolve archive to absolute path before any directory change
    local archive_name
    if [[ "$ARCHIVE" == /* ]]; then
        archive_name="$ARCHIVE"
    else
        archive_name="$(pwd)/$ARCHIVE"
    fi

    local tar_opts=("-x" "-v" "-f")
    [ -n "$COMP_FLAG" ] && tar_opts=("-x" "$COMP_FLAG" "-v" "-f")

    # Auto-detect compression if not specified
    if [ -z "$COMPRESSION" ]; then
        case "$archive_name" in
            *.tar.gz|*.tgz)
                COMP_FLAG="-z"
                info "Auto-detected gzip compression"
                ;;
            *.tar.bz2|*.tbz2)
                COMP_FLAG="-j"
                info "Auto-detected bzip2 compression"
                ;;
            *.tar.xz|*.txz)
                COMP_FLAG="-J"
                info "Auto-detected xz compression"
                ;;
            *.tar.lz|*.tlz)
                COMP_FLAG="--lzip"
                info "Auto-detected lzip compression"
                ;;
            *.tar)
                info "No compression detected"
                ;;
            *)
                warn "Cannot auto-detect compression from filename, trying without compression"
                ;;
        esac
        if [ -n "$COMP_FLAG" ]; then
            tar_opts=("-x" "$COMP_FLAG" "-v" "-f")
        else
            tar_opts=("-x" "-v" "-f")
        fi
    fi

    if [ ! -f "$archive_name" ]; then
        error "Archive file does not exist: $archive_name"
    fi

    info "Extracting archive: $archive_name"
    info "Destination directory: $WORKING_DIR"

    # Resolve destination to absolute path
    local dest_dir
    dest_dir=$(cd "$WORKING_DIR" && pwd) || error "Cannot access working directory: $WORKING_DIR"

    # List all entries in the archive
    info "Listing archive entries..."
    local list_opts=("-t" "-f")
    [ -n "$COMP_FLAG" ] && list_opts=("-t" "$COMP_FLAG" "-f")
    local archive_contents
    archive_contents=$(mktemp) || error "Cannot create temp file"
    TEMP_FILES+=("$archive_contents")
    tar "${list_opts[@]}" "$archive_name" > "$archive_contents" 2>/dev/null \
        || { rm -f "$archive_contents"; error "Failed to list archive contents: $archive_name"; }

    # Validate each entry - reject path traversal attempts
    info "Validating archive entries..."
    local validated_contents
    validated_contents=$(mktemp) || error "Cannot create temp file"
    TEMP_FILES+=("$validated_contents")
    local rejected=0
    while IFS= read -r entry; do
        if validate_entry "$entry"; then
            echo "$entry" >> "$validated_contents"
        else
            warn "Rejecting unsafe entry: $entry"
            rejected=$((rejected + 1))
        fi
    done < "$archive_contents"
    rm -f "$archive_contents"

    if [ "$rejected" -gt 0 ]; then
        warn "$rejected unsafe path(s) rejected from archive"
    fi

    if [ ! -s "$validated_contents" ]; then
        rm -f "$validated_contents"
        error "No safe entries found in archive"
    fi

    # Apply select/skip filters on validated entries
    local filtered_contents
    filtered_contents=$(mktemp) || error "Cannot create temp file"
    TEMP_FILES+=("$filtered_contents")
    cp "$validated_contents" "$filtered_contents"
    rm -f "$validated_contents"

    if [ -n "$SELECT_FILE" ]; then
        info "Applying select filter"
        local select_temp
        select_temp=$(mktemp)
        TEMP_FILES+=("$select_temp")
        read_file_list "$SELECT_FILE" "Select" > "$select_temp"

        local selected
        selected=$(mktemp)
        TEMP_FILES+=("$selected")
        while IFS= read -r pattern; do
            grep -Fx -e "${pattern}" -e "./${pattern}" "$filtered_contents" || true
        done < "$select_temp" > "$selected"

        rm -f "$select_temp" "$filtered_contents"
        filtered_contents="$selected"
    fi

    if [ -n "$SKIP_FILE" ]; then
        info "Applying skip filter"
        local skip_temp
        skip_temp=$(mktemp)
        TEMP_FILES+=("$skip_temp")
        read_file_list "$SKIP_FILE" "Skip" > "$skip_temp"

        local remaining
        remaining=$(mktemp)
        TEMP_FILES+=("$remaining")
        cp "$filtered_contents" "$remaining"

        while IFS= read -r pattern; do
            grep -Fxv -e "${pattern}" -e "./${pattern}" "$remaining" > "${remaining}.new" || true
            mv "${remaining}.new" "$remaining"
        done < "$skip_temp"

        rm -f "$skip_temp" "$filtered_contents"
        filtered_contents="$remaining"
    fi

    if [ ! -s "$filtered_contents" ]; then
        rm -f "$filtered_contents"
        error "No files to extract after applying filters"
    fi

    # Extract into a private staging directory with restrictive permissions
    local staging_dir
    staging_dir=$(mktemp -d) || error "Cannot create staging directory"
    TEMP_DIRS+=("$staging_dir")
    chmod 700 "$staging_dir"
    info "Extracting into staging directory..."
    # --no-same-owner / --no-same-permissions prevent the archive from imposing
    # arbitrary ownership or permission bits on the extracted files.
    if ! tar "${tar_opts[@]}" "$archive_name" -C "$staging_dir" -T "$filtered_contents" \
             --no-same-owner --no-same-permissions 2>/dev/null; then
         rm -f "$filtered_contents"
         rm -rf "$staging_dir"
         error "Extraction failed"
     fi

    # Move only expected files to the final destination
    info "Moving validated files to destination: $dest_dir"
    local move_count=0
    while IFS= read -r entry; do
        local clean_entry="${entry#./}"   # strip leading ./
        clean_entry="${clean_entry%/}"    # strip trailing /
        [ -z "$clean_entry" ] && continue

        local src="$staging_dir/$clean_entry"
        if [ -e "$src" ]; then
            # Reject symlinks and special files (devices, FIFOs, sockets, …).
            # Only plain regular files are permitted in the destination.
            if [[ -L "$src" ]] || [[ ! -f "$src" ]]; then
                warn "Skipping non-regular file (symlink or special file): $clean_entry"
                continue
            fi
            local dest_path="$dest_dir/$clean_entry"
            mkdir -p "$(dirname "$dest_path")"
            mv -f "$src" "$dest_path"
            # Normalize permissions so the archive cannot leave world-writable
            # or executable bits that it should not have.
            chmod 0644 "$dest_path"
            move_count=$((move_count + 1))
        else
            warn "Expected entry not found after extraction: $clean_entry"
        fi
    done < "$filtered_contents"

    # Cleanup
    rm -f "$filtered_contents"
    rm -rf "$staging_dir"

    info "Moved $move_count item(s) to destination"
    info "Extraction completed successfully"
}

# Main execution
case "$MODE" in
    create)
        create_archive
        ;;
    extract)
        extract_archive
        ;;
esac

info "Operation completed successfully!"
exit 0
