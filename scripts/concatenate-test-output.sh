#!/bin/bash

############################################################################
## concatenate-test-output.sh
## Script to concatenate all .txt files in the surefire-reports directory
## into a single artifact that can be stored in CI.
##
## Enhanced for GitHub Actions with better error handling, logging,
## and configurable input/output paths.
##
## Usage: ./concatenate-test-output.sh [--output-dir=path] [--verbose] [--dry-run]
## Output: Concatenates test output files to specified directory
############################################################################

set -e

# Configuration
OUTPUT_DIR="${GITHUB_WORKSPACE:-$(pwd)}/test-output-artifacts"
VERBOSE=false
DRY_RUN=false
WORKSPACE_DIR="${GITHUB_WORKSPACE:-$(pwd)}"
SUREFIRE_DIR="target/surefire-reports"
MODULE_PATTERN="*/"
FILE_EXTENSIONS="txt,xml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_debug() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}🔍 $1${NC}"
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --workspace)
            WORKSPACE_DIR="$2"
            shift 2
            ;;
        --surefire-dir)
            SUREFIRE_DIR="$2"
            shift 2
            ;;
        --module-pattern)
            MODULE_PATTERN="$2"
            shift 2
            ;;
        --file-extensions)
            FILE_EXTENSIONS="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [--output-dir=path] [--verbose] [--dry-run] [--workspace=path] [--surefire-dir=path] [--module-pattern=pattern] [--file-extensions=ext1,ext2]"
            echo ""
            echo "Options:"
            echo "  --output-dir        Output directory for concatenated files (default: ./test-output-artifacts)"
            echo "  --verbose           Enable verbose logging"
            echo "  --dry-run           Show what would be done without making changes"
            echo "  --workspace         Workspace directory (default: GITHUB_WORKSPACE or current dir)"
            echo "  --surefire-dir      Surefire reports directory name (default: target/surefire-reports)"
            echo "  --module-pattern    Pattern to find modules (default: */)"
            echo "  --file-extensions   Comma-separated list of file extensions to process (default: txt,xml)"
            echo "  --help              Show this help message"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Change to workspace directory
cd "$WORKSPACE_DIR"
log_info "Working in directory: $(pwd)"

# Create output directory
if [[ "$DRY_RUN" == "true" ]]; then
    log_info "DRY RUN: Would create output directory: $OUTPUT_DIR"
else
    mkdir -p "$OUTPUT_DIR"
    log_info "Created output directory: $OUTPUT_DIR"
fi

# Function to check if directory contains test reports
has_test_reports() {
    local dir="$1"
    local surefire_path="$dir/$SUREFIRE_DIR"
    
    if [[ -d "$surefire_path" ]]; then
        # Check if it contains test report files
        for ext in ${FILE_EXTENSIONS//,/ }; do
            if [[ -n "$(find "$surefire_path" -name "*.$ext" -type f 2>/dev/null | head -1)" ]]; then
                return 0
            fi
        done
    fi
    
    return 1
}

# Function to concatenate test output from a module
concatenate_module_output() {
    local module_dir="$1"
    local module_name
    local output_file
    local surefire_path
    local file_count=0
    
    # Extract module name
    module_name=$(basename "${module_dir%/}")
    output_file="$OUTPUT_DIR/${module_name}-test-output.txt"
    surefire_path="$module_dir/$SUREFIRE_DIR"
    
    log_debug "Processing module: $module_name"
    
    if has_test_reports "$module_dir"; then
        log_info "Processing module: $module_name"
        log_debug "Output file: $output_file"
        
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "DRY RUN: Would concatenate test output for $module_name to $output_file"
            return
        fi
        
        # Create output file with header
        cat > "$output_file" << EOF
=== Test Output for ${module_name} ===
Generated at: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
Workspace: $WORKSPACE_DIR
Module: $module_name
Surefire Directory: $surefire_path
==========================================

EOF
        
        # Process each file extension
        for ext in ${FILE_EXTENSIONS//,/ }; do
            log_debug "Processing .$ext files for $module_name"
            
            # Find and sort files by extension
            if [[ -n "$(find "$surefire_path" -name "*.$ext" -type f 2>/dev/null | head -1)" ]]; then
                find "$surefire_path" -name "*.$ext" -type f | sort | while read -r test_file; do
                    file_count=$((file_count + 1))
                    log_debug "Processing: $(basename "$test_file")"
                    
                    # Add file separator
                    echo "" >> "$output_file"
                    echo "--- File: $(basename "$test_file") ---" >> "$output_file"
                    echo "Path: $test_file" >> "$output_file"
                    echo "Size: $(stat -c%s "$test_file" 2>/dev/null || stat -f%z "$test_file" 2>/dev/null || echo "unknown") bytes" >> "$output_file"
                    echo "Modified: $(stat -c%y "$test_file" 2>/dev/null || stat -f%Sm "$test_file" 2>/dev/null || echo "unknown")" >> "$output_file"
                    echo "--- Content ---" >> "$output_file"
                    
                    # Concatenate file content
                    cat "$test_file" >> "$output_file"
                    
                    echo "" >> "$output_file"
                    echo "--- End of $(basename "$test_file") ---" >> "$output_file"
                    echo "" >> "$output_file"
                done
            else
                log_debug "No .$ext files found in $surefire_path"
            fi
        done
        
        if [[ $file_count -gt 0 ]]; then
            log_success "Concatenated test output for $module_name to $output_file ($file_count files)"
        else
            log_warning "No test files found for $module_name"
            # Remove empty output file
            rm -f "$output_file"
        fi
    else
        log_debug "No test reports found in $module_name"
    fi
}

# Function to generate summary report
generate_summary() {
    local summary_file="$OUTPUT_DIR/concatenation-summary.txt"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would generate summary report: $summary_file"
        return
    fi
    
    log_info "Generating concatenation summary..."
    
    cat > "$summary_file" << EOF
Test Output Concatenation Summary
=================================
Generated at: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
Workspace: $WORKSPACE_DIR
Output Directory: $OUTPUT_DIR
Surefire Directory: $SUREFIRE_DIR
Module Pattern: $MODULE_PATTERN
File Extensions: $FILE_EXTENSIONS

Processed Modules:
EOF
    
    # Count and list processed modules
    local total_modules=0
    local processed_modules=0
    local total_files=0
    
    for module_dir in $MODULE_PATTERN; do
        if [[ -d "$module_dir" ]]; then
            total_modules=$((total_modules + 1))
            module_name=$(basename "${module_dir%/}")
            
            if has_test_reports "$module_dir"; then
                processed_modules=$((processed_modules + 1))
                
                # Count files in this module
                local module_files=0
                for ext in ${FILE_EXTENSIONS//,/ }; do
                    local ext_count=$(find "$module_dir/$SUREFIRE_DIR" -name "*.$ext" -type f 2>/dev/null | wc -l)
                    module_files=$((module_files + ext_count))
                done
                total_files=$((total_files + module_files))
                
                echo "  ✅ $module_name ($module_files files)" >> "$summary_file"
            else
                echo "  ❌ $module_name (no reports)" >> "$summary_file"
            fi
        fi
    done
    
    echo "" >> "$summary_file"
    echo "Summary:" >> "$summary_file"
    echo "  Total modules checked: $total_modules" >> "$summary_file"
    echo "  Modules with reports: $processed_modules" >> "$summary_file"
    echo "  Total test files processed: $total_files" >> "$summary_file"
    echo "  Output files created: $processed_modules" >> "$summary_file"
    echo "  Output directory: $OUTPUT_DIR" >> "$summary_file"
    
    log_success "Summary report generated: $summary_file"
}

# Function to validate concatenated output
validate_concatenated_output() {
    local validation_errors=0
    
    log_info "Validating concatenated output..."
    
    for module_dir in $MODULE_PATTERN; do
        if [[ -d "$module_dir" ]]; then
            module_name=$(basename "${module_dir%/}")
            output_file="$OUTPUT_DIR/${module_name}-test-output.txt"
            
            if has_test_reports "$module_dir"; then
                if [[ -f "$output_file" ]]; then
                    # Check if output file has content
                    local file_size=$(stat -c%s "$output_file" 2>/dev/null || stat -f%z "$output_file" 2>/dev/null || echo "0")
                    if [[ "$file_size" -gt 100 ]]; then
                        log_debug "✅ $module_name: Output file validated ($file_size bytes)"
                    else
                        log_warning "⚠️  $module_name: Output file seems too small ($file_size bytes)"
                        validation_errors=$((validation_errors + 1))
                    fi
                else
                    log_error "❌ $module_name: Output file not created"
                    validation_errors=$((validation_errors + 1))
                fi
            fi
        fi
    done
    
    if [[ $validation_errors -eq 0 ]]; then
        log_success "All concatenated output validated successfully"
        return 0
    else
        log_warning "Validation completed with $validation_errors warnings"
        return 1
    fi
}

# Main execution
main() {
    log_info "=== QQQ Test Output Concatenator (GitHub Actions Enhanced) ==="
    log_info "Workspace: $WORKSPACE_DIR"
    log_info "Output directory: $OUTPUT_DIR"
    log_info "Surefire directory: $SUREFIRE_DIR"
    log_info "Module pattern: $MODULE_PATTERN"
    log_info "File extensions: $FILE_EXTENSIONS"
    log_info "Dry run: $DRY_RUN"
    log_info "Verbose: $VERBOSE"
    echo ""
    
    # Find and process modules
    local total_modules=0
    local processed_modules=0
    local errors=0
    
    log_info "Scanning for modules with test reports..."
    
    for module_dir in $MODULE_PATTERN; do
        if [[ -d "$module_dir" ]]; then
            total_modules=$((total_modules + 1))
            
            if concatenate_module_output "$module_dir"; then
                processed_modules=$((processed_modules + 1))
            else
                errors=$((errors + 1))
            fi
        fi
    done
    
    echo ""
    log_info "Concatenation Summary:"
    log_info "  Total modules found: $total_modules"
    log_info "  Successfully processed: $processed_modules"
    log_info "  Errors: $errors"
    
    # Generate summary report
    generate_summary
    
    # Validate concatenated output
    if ! validate_concatenated_output; then
        log_warning "Some validation warnings occurred"
    fi
    
    # Show final output
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: No actual files were created"
    else
        log_success "=== Test output concatenation complete ==="
        log_info "Concatenated files created in: $OUTPUT_DIR"
        
        if [[ "$VERBOSE" == "true" ]]; then
            log_info "Created files:"
            find "$OUTPUT_DIR" -name "*-test-output.txt" -type f | sort | while read -r file; do
                local file_size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo "unknown")
                log_info "  📄 $(basename "$file") ($file_size bytes)"
            done
        fi
    fi
    
    # Exit with error code if there were errors
    if [[ $errors -gt 0 ]]; then
        log_error "Concatenation completed with $errors errors"
        exit 1
    fi
}

# Run main function
main "$@"
