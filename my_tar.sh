#!/bin/bash

# Script: my_tar.sh
# Description: Archive/Extract files using tar with compression options and selective file handling
# Usage: my_tar.sh [--dir=PATH] <archive.tar> --mode=create|extract [--comp=GZ|BZ2|XZ|LZ] [--select=<package_list.txt>] [--skip=<skip_list.txt>]

set -e  # Exit on error

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
            COMP_FLAG="z"
            ARCHIVE_EXT=".gz"
            ;;
        BZ2)
            COMP_FLAG="j"
            ARCHIVE_EXT=".bz2"
            ;;
        XZ)
            COMP_FLAG="J"
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
    local tar_opts="c${COMP_FLAG}vf"
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
        read_file_list "$SELECT_FILE" "Select" > "$temp_list"
        final_list="$temp_list"
    else
        # Use all files in current directory
        temp_list=$(mktemp)
        find . -maxdepth 1 ! -path . | sed 's|^\./||' > "$temp_list"
        final_list="$temp_list"
    fi
    
    # Apply skip list if specified
    if [ -n "$SKIP_FILE" ]; then
        info "Reading skip file: $SKIP_FILE"
        local skip_temp=$(mktemp)
        read_file_list "$SKIP_FILE" "Skip" > "$skip_temp"
        
        # Filter out skipped items
        local filtered_list=$(mktemp)
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
    
    if [ $final_list -gt 0 ]; then
        error "all file(s)/directory(ies) not found"
    fi
    
    # Create the archive using tar with file list
    info "Creating tar archive..."
    if [ "$COMPRESSION" = "LZ" ]; then
        tar cvf - -T "$final_list" --ignore-failed-read 2>/dev/null | lzip > "$archive_name"
    else
        tar $tar_opts "$archive_name" -T "$final_list" --ignore-failed-read 2>/dev/null
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
    local tar_opts="x${COMP_FLAG}vf"
    local archive_name="$ARCHIVE"
    
    # Auto-detect compression if not specified
    if [ -z "$COMPRESSION" ]; then
        case "$archive_name" in
            *.tar.gz|*.tgz)
                COMP_FLAG="z"
                info "Auto-detected gzip compression"
                ;;
            *.tar.bz2|*.tbz2)
                COMP_FLAG="j"
                info "Auto-detected bzip2 compression"
                ;;
            *.tar.xz|*.txz)
                COMP_FLAG="J"
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
        tar_opts="x${COMP_FLAG}vf"
    fi
    
    if [ ! -f "$archive_name" ]; then
        error "Archive file does not exist: $archive_name"
    fi
    
    info "Extracting archive: $archive_name"
    info "Destination directory: $WORKING_DIR"
    
    cd "$WORKING_DIR" || error "Cannot change to working directory: $WORKING_DIR"
    
    # Extract with filters if specified
    if [ -n "$SELECT_FILE" ] || [ -n "$SKIP_FILE" ]; then
        # List contents of archive
        local archive_contents=$(mktemp)
        if [[ "$tar_opts" =~ "lzip" ]]; then
            tar t${COMP_FLAG}f "$archive_name" > "$archive_contents" 2>/dev/null
        else
            tar t${COMP_FLAG}f "$archive_name" > "$archive_contents" 2>/dev/null
        fi
        
        local filtered_contents=$(mktemp)
        cp "$archive_contents" "$filtered_contents"
        
        # Apply select filter
        if [ -n "$SELECT_FILE" ]; then
            info "Applying select filter"
            local select_temp=$(mktemp)
            read_file_list "$SELECT_FILE" "Select" > "$select_temp"
            
            local selected=$(mktemp)
            while IFS= read -r pattern; do
                grep "^${pattern}" "$filtered_contents" || true
            done < "$select_temp" > "$selected"
            
            rm -f "$select_temp"
            mv "$selected" "$filtered_contents"
        fi
        
        # Apply skip filter
        if [ -n "$SKIP_FILE" ]; then
            info "Applying skip filter"
            local skip_temp=$(mktemp)
            read_file_list "$SKIP_FILE" "Skip" > "$skip_temp"
            
            local remaining=$(mktemp)
            cp "$filtered_contents" "$remaining"
            
            while IFS= read -r pattern; do
                grep -v "^${pattern}" "$remaining" > "${remaining}.new" || true
                mv "${remaining}.new" "$remaining"
            done < "$skip_temp"
            
            rm -f "$skip_temp"
            mv "$remaining" "$filtered_contents"
        fi
        
        if [ ! -s "$filtered_contents" ]; then
            rm -f "$archive_contents" "$filtered_contents"
            error "No files to extract after applying filters"
        fi
        
        # Extract filtered files
        info "Extracting filtered files..."
        tar $tar_opts "$archive_name" -T "$filtered_contents" 2>/dev/null
        
        rm -f "$archive_contents" "$filtered_contents"
    else
        # Extract all
        info "Extracting all files..."
        tar $tar_opts "$archive_name" 2>/dev/null
    fi
    
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
