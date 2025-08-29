#!/bin/bash

############################################################################
## collect-jacoco-reports.sh
## Script to collect all JaCoCo reports from different modules into a
## single directory for easier artifact storage in CI.
##
## Enhanced for GitHub Actions with better error handling, logging,
## and configurable output paths.
##
## Usage: ./collect-jacoco-reports.sh [--output-dir=path] [--verbose] [--dry-run]
## Output: Collects JaCoCo reports to specified directory
############################################################################

set -e

# Configuration
OUTPUT_DIR="${GITHUB_WORKSPACE:-$(pwd)}/jacoco-reports"
VERBOSE=false
DRY_RUN=false
WORKSPACE_DIR="${GITHUB_WORKSPACE:-$(pwd)}"
JACOCO_DIR="target/site/jacoco"
MODULE_PATTERN="*/"

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
        --jacoco-dir)
            JACOCO_DIR="$2"
            shift 2
            ;;
        --module-pattern)
            MODULE_PATTERN="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [--output-dir=path] [--verbose] [--dry-run] [--workspace=path] [--jacoco-dir=path] [--module-pattern=pattern]"
            echo ""
            echo "Options:"
            echo "  --output-dir        Output directory for collected reports (default: ./jacoco-reports)"
            echo "  --verbose           Enable verbose logging"
            echo "  --dry-run           Show what would be done without making changes"
            echo "  --workspace         Workspace directory (default: GITHUB_WORKSPACE or current dir)"
            echo "  --jacoco-dir        JaCoCo directory name (default: target/site/jacoco)"
            echo "  --module-pattern    Pattern to find modules (default: */)"
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

# Function to check if directory contains JaCoCo reports
has_jacoco_reports() {
    local dir="$1"
    local jacoco_path="$dir/$JACOCO_DIR"
    
    if [[ -d "$jacoco_path" ]]; then
        # Check if it contains actual JaCoCo files
        if [[ -f "$jacoco_path/index.html" ]] || [[ -f "$jacoco_path/jacoco.xml" ]]; then
            return 0
        fi
    fi
    
    return 1
}

# Function to collect JaCoCo reports from a module
collect_module_reports() {
    local module_dir="$1"
    local module_name
    local target_dir
    local jacoco_path
    
    # Extract module name
    module_name=$(basename "${module_dir%/}")
    target_dir="$OUTPUT_DIR/$module_name"
    jacoco_path="$module_dir/$JACOCO_DIR"
    
    log_debug "Checking module: $module_name"
    
    if has_jacoco_reports "$module_dir"; then
        log_info "Collecting JaCoCo reports for module: $module_name"
        log_debug "Source: $jacoco_path"
        log_debug "Target: $target_dir"
        
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "DRY RUN: Would copy JaCoCo reports from $jacoco_path to $target_dir"
            return
        fi
        
        # Copy JaCoCo reports
        if cp -r "$jacoco_path" "$target_dir"; then
            log_success "Copied JaCoCo reports for $module_name to $target_dir"
            
            # Show what was copied
            if [[ "$VERBOSE" == "true" ]]; then
                log_debug "Files copied:"
                find "$target_dir" -type f | head -10 | while read -r file; do
                    log_debug "  $(basename "$file")"
                done
            fi
        else
            log_error "Failed to copy JaCoCo reports for $module_name"
            return 1
        fi
    else
        log_debug "No JaCoCo reports found in $module_name"
    fi
}

# Function to generate summary report
generate_summary() {
    local summary_file="$OUTPUT_DIR/collection-summary.txt"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would generate summary report: $summary_file"
        return
    fi
    
    log_info "Generating collection summary..."
    
    cat > "$summary_file" << EOF
JaCoCo Reports Collection Summary
=================================
Generated at: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
Workspace: $WORKSPACE_DIR
Output Directory: $OUTPUT_DIR
JaCoCo Directory: $JACOCO_DIR
Module Pattern: $MODULE_PATTERN

Collected Reports:
EOF
    
    # Count and list collected reports
    local total_modules=0
    local collected_modules=0
    
    for module_dir in $MODULE_PATTERN; do
        if [[ -d "$module_dir" ]]; then
            total_modules=$((total_modules + 1))
            module_name=$(basename "${module_dir%/}")
            
            if has_jacoco_reports "$module_dir"; then
                collected_modules=$((collected_modules + 1))
                echo "  ✅ $module_name" >> "$summary_file"
            else
                echo "  ❌ $module_name (no reports)" >> "$summary_file"
            fi
        fi
    done
    
    echo "" >> "$summary_file"
    echo "Summary:" >> "$summary_file"
    echo "  Total modules checked: $total_modules" >> "$summary_file"
    echo "  Modules with reports: $collected_modules" >> "$summary_file"
    echo "  Reports collected to: $OUTPUT_DIR" >> "$summary_file"
    
    log_success "Summary report generated: $summary_file"
}

# Function to validate collected reports
validate_collected_reports() {
    local validation_errors=0
    
    log_info "Validating collected reports..."
    
    for module_dir in $MODULE_PATTERN; do
        if [[ -d "$module_dir" ]]; then
            module_name=$(basename "${module_dir%/}")
            target_dir="$OUTPUT_DIR/$module_name"
            
            if has_jacoco_reports "$module_dir"; then
                if [[ -d "$target_dir" ]]; then
                    # Check if essential files are present
                    if [[ -f "$target_dir/index.html" ]] || [[ -f "$target_dir/jacoco.xml" ]]; then
                        log_debug "✅ $module_name: Reports validated"
                    else
                        log_warning "⚠️  $module_name: Missing essential JaCoCo files"
                        validation_errors=$((validation_errors + 1))
                    fi
                else
                    log_error "❌ $module_name: Target directory not created"
                    validation_errors=$((validation_errors + 1))
                fi
            fi
        fi
    done
    
    if [[ $validation_errors -eq 0 ]]; then
        log_success "All collected reports validated successfully"
        return 0
    else
        log_warning "Validation completed with $validation_errors warnings"
        return 1
    fi
}

# Main execution
main() {
    log_info "=== QQQ JaCoCo Report Collector (GitHub Actions Enhanced) ==="
    log_info "Workspace: $WORKSPACE_DIR"
    log_info "Output directory: $OUTPUT_DIR"
    log_info "JaCoCo directory: $JACOCO_DIR"
    log_info "Module pattern: $MODULE_PATTERN"
    log_info "Dry run: $DRY_RUN"
    log_info "Verbose: $VERBOSE"
    echo ""
    
    # Find and process modules
    local total_modules=0
    local processed_modules=0
    local errors=0
    
    log_info "Scanning for modules with JaCoCo reports..."
    
    for module_dir in $MODULE_PATTERN; do
        if [[ -d "$module_dir" ]]; then
            total_modules=$((total_modules + 1))
            
            if collect_module_reports "$module_dir"; then
                processed_modules=$((processed_modules + 1))
            else
                errors=$((errors + 1))
            fi
        fi
    done
    
    echo ""
    log_info "Collection Summary:"
    log_info "  Total modules found: $total_modules"
    log_info "  Successfully processed: $processed_modules"
    log_info "  Errors: $errors"
    
    # Generate summary report
    generate_summary
    
    # Validate collected reports
    if ! validate_collected_reports; then
        log_warning "Some validation warnings occurred"
    fi
    
    # Show final output
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: No actual files were copied"
    else
        log_success "=== JaCoCo report collection complete ==="
        log_info "Reports collected to: $OUTPUT_DIR"
        
        if [[ "$VERBOSE" == "true" ]]; then
            log_info "Collected reports:"
            find "$OUTPUT_DIR" -type d -maxdepth 1 | sort | while read -r dir; do
                if [[ "$dir" != "$OUTPUT_DIR" ]]; then
                    module_name=$(basename "$dir")
                    log_info "  📁 $module_name"
                fi
            done
        fi
    fi
    
    # Exit with error code if there were errors
    if [[ $errors -gt 0 ]]; then
        log_error "Collection completed with $errors errors"
        exit 1
    fi
}

# Run main function
main "$@"
