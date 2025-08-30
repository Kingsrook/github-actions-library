#!/bin/bash

############################################################################
## calculate-version.sh
## Intelligent version calculation for GitFlow branching strategy
## 
## This script determines the appropriate version based on:
## - Current branch name
## - Current version in pom.xml
## - GitFlow conventions
##
## Enhanced for GitHub Actions with better error handling and logging
##
## Usage: ./calculate-version.sh [--dry-run] [--verbose] [--output-format=json|text]
## Output: Sets version in pom.xml and prints the new version
############################################################################

set -e

# Configuration
POM_FILE="pom.xml"
DRY_RUN=false
VERBOSE=false
OUTPUT_FORMAT="text"
WORKSPACE_DIR="${GITHUB_WORKSPACE:-$(pwd)}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    if [[ "$OUTPUT_FORMAT" != "json" ]]; then
        echo -e "${BLUE}ℹ️  $1${NC}"
    fi
}

log_success() {
    if [[ "$OUTPUT_FORMAT" != "json" ]]; then
        echo -e "${GREEN}✅ $1${NC}"
    fi
}

log_warning() {
    if [[ "$OUTPUT_FORMAT" != "json" ]]; then
        echo -e "${YELLOW}⚠️  $1${NC}"
    fi
}

log_error() {
    # Always show errors, even in JSON mode
    echo -e "${RED}❌ $1${NC}" >&2
}

log_debug() {
    if [[ "$VERBOSE" == "true" ]] && [[ "$OUTPUT_FORMAT" != "json" ]]; then
        echo -e "${BLUE}🔍 $1${NC}"
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --output-format)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        --workspace)
            WORKSPACE_DIR="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [--dry-run] [--verbose] [--output-format=json|text] [--workspace=path]"
            echo ""
            echo "Options:"
            echo "  --dry-run           Show what would be done without making changes"
            echo "  --verbose           Enable verbose logging"
            echo "  --output-format     Output format: json or text (default: text)"
            echo "  --workspace         Workspace directory (default: GITHUB_WORKSPACE or current dir)"
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

# Validate pom.xml exists
if [[ ! -f "$POM_FILE" ]]; then
    log_error "pom.xml not found in $(pwd)"
    exit 1
fi

# Get current branch and version
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
CURRENT_VERSION=$(grep '<revision>' "$POM_FILE" | sed 's/.*<revision>//;s/<.*//')

if [[ -z "$CURRENT_VERSION" ]]; then
    log_error "Could not extract version from $POM_FILE"
    exit 1
fi

log_info "Current branch: $CURRENT_BRANCH"
log_info "Current version: $CURRENT_VERSION"

# Function to extract version components
extract_version_parts() {
    local version=$1
    log_debug "Extracting version parts from: $version"
    
    # Handle RC versions like 1.5.0-RC.1
    if [[ "$version" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)-RC\.[0-9]+$ ]]; then
        MAJOR=${BASH_REMATCH[1]}
        MINOR=${BASH_REMATCH[2]}
        PATCH=${BASH_REMATCH[3]}
        log_debug "RC version detected: MAJOR=$MAJOR, MINOR=$MINOR, PATCH=$PATCH"
    # Handle SNAPSHOT versions like 1.5.0-SNAPSHOT
    elif [[ "$version" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)-SNAPSHOT$ ]]; then
        MAJOR=${BASH_REMATCH[1]}
        MINOR=${BASH_REMATCH[2]}
        PATCH=${BASH_REMATCH[3]}
        log_debug "SNAPSHOT version detected: MAJOR=$MAJOR, MINOR=$MINOR, PATCH=$PATCH"
    # Handle stable versions like 1.5.0
    elif [[ "$version" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
        MAJOR=${BASH_REMATCH[1]}
        MINOR=${BASH_REMATCH[2]}
        PATCH=${BASH_REMATCH[3]}
        log_debug "Stable version detected: MAJOR=$MAJOR, MINOR=$MINOR, PATCH=$PATCH"
    else
        log_error "Cannot parse version format: $version"
        exit 1
    fi
}

# Function to calculate next version based on branch type
calculate_next_version() {
    local branch=$1
    log_debug "Calculating version for branch: $branch"
    
    case "$branch" in
        "develop")
            # Check if we just merged a release branch back to develop
            # Look for very specific patterns that indicate a release completion
            # Only look at recent commits to avoid historical merges triggering bumps
            RECENT_RELEASE_MERGES=$(git log --oneline -10 --grep="Merge.*release.*into.*develop" --grep="Merge.*release.*back.*develop" --grep="Bump.*version.*after.*release.*v" --since="3 days ago" 2>/dev/null || true)
            
            # Also check if current version suggests we're ready for next cycle
            if [[ -n "$RECENT_RELEASE_MERGES" ]] || [[ "$CURRENT_VERSION" =~ -RC\.[0-9]+$ ]] || [[ "$CURRENT_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                # We just merged a release or have an RC/stable version, bump to next
                NEW_VERSION="$MAJOR.$((MINOR + 1)).0-SNAPSHOT"
                log_debug "Develop branch: Bumping to next minor version: $NEW_VERSION"
            else
                # Keep current SNAPSHOT version - no recent release activity
                NEW_VERSION="$CURRENT_VERSION"
                log_debug "Develop branch: Keeping current version: $NEW_VERSION"
            fi
            ;;
            
        "main")
            # Main should always have stable versions
            # Check if we just merged a release branch and need to convert RC to stable
            RECENT_RELEASE_MERGES=$(git log --oneline -5 --grep="Merge.*release.*into.*main" --grep="Merge.*release.*back.*main" --grep="Merge.*R.*back.*main" || true)

            if [[ -n "$RECENT_RELEASE_MERGES" ]] && [[ "$CURRENT_VERSION" =~ -RC\.[0-9]+$ ]]; then
                # We just merged a release and have an RC version, convert to stable
                NEW_VERSION="${CURRENT_VERSION%-RC.*}"
                echo "Release merge detected, converting RC version to stable: $NEW_VERSION"
            else
                # No recent release merge or already stable, keep current version
                NEW_VERSION="$CURRENT_VERSION"
            fi
            ;;            

        release/*)
            # Extract major.minor from branch name (e.g., release/1.5 -> 1.5.0-RC.n)
            if [[ "$branch" =~ release/([0-9]+)\.([0-9]+) ]]; then
                BRANCH_MAJOR=${BASH_REMATCH[1]}
                BRANCH_MINOR=${BASH_REMATCH[2]}
                
                # Check if we already have an RC version
                if [[ "$CURRENT_VERSION" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)-RC\.([0-9]+)$ ]]; then
                    # Extract current RC number and increment it
                    CURRENT_RC=${BASH_REMATCH[4]}
                    NEW_RC=$((CURRENT_RC + 1))
                    NEW_VERSION="$BRANCH_MAJOR.$BRANCH_MINOR.0-RC.$NEW_RC"
                    log_debug "Release branch: Incrementing RC from $CURRENT_RC to $NEW_RC: $NEW_VERSION"
                else
                    # First RC for this release
                    NEW_VERSION="$BRANCH_MAJOR.$BRANCH_MINOR.0-RC.1"
                    log_debug "Release branch: First RC: $NEW_VERSION"
                fi
            else
                log_error "Invalid release branch format: $branch"
                exit 1
            fi
            ;;
            
        hotfix/*)
            # Bump patch version for hotfix
            NEW_VERSION="$MAJOR.$MINOR.$((PATCH + 1))"
            log_debug "Hotfix branch: Bumping patch version: $NEW_VERSION"
            ;;
            
        feature/*|*)
            # Feature branches inherit version from develop, no changes
            NEW_VERSION="$CURRENT_VERSION"
            log_debug "Feature branch: Inheriting version: $NEW_VERSION"
            ;;
    esac
}

# Function to set version using Maven
set_version() {
    local new_version=$1
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would set version to: $new_version"
        log_info "Command: mvn versions:set-property -Dproperty=revision -DnewVersion=$new_version -DgenerateBackupPoms=false"
        return
    fi
    
    log_info "Setting version to: $new_version"
    
    # Use Maven versions plugin to set version
    # In JSON mode, suppress all Maven output to avoid interfering with JSON parsing
    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        if ! mvn versions:set-property -Dproperty=revision -DnewVersion="$new_version" -DgenerateBackupPoms=false -q -B >/dev/null 2>&1; then
            log_error "Failed to set version using Maven"
            exit 1
        fi
    else
        if ! mvn versions:set-property -Dproperty=revision -DnewVersion="$new_version" -DgenerateBackupPoms=false; then
            log_error "Failed to set version using Maven"
            exit 1
        fi
    fi
    
    # Verify the change
    ACTUAL_VERSION=$(grep "<revision>" "$POM_FILE" | sed 's/.*<revision>//;s/<.*//')
    if [[ "$ACTUAL_VERSION" == "$new_version" ]]; then
        log_success "Version successfully updated to: $ACTUAL_VERSION"
    else
        log_error "Version update failed. Expected: $new_version, Got: $ACTUAL_VERSION"
        exit 1
    fi
}

# Function to output results in specified format
output_results() {
    local old_version=$1
    local new_version=$2
    local branch=$3
    
    case "$OUTPUT_FORMAT" in
        "json")
            cat << EOF
{
  "success": true,
  "old_version": "$old_version",
  "new_version": "$new_version",
  "branch": "$branch",
  "version_changed": $(if [[ "$old_version" != "$new_version" ]]; then echo "true"; else echo "false"; fi),
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
            ;;
        "text"|*)
            if [[ "$old_version" != "$new_version" ]]; then
                log_success "Version change: $old_version → $new_version"
            else
                log_info "No version change needed"
            fi
            ;;
    esac
}

# Main execution
main() {
    log_info "=== QQQ Version Calculator (GitHub Actions Enhanced) ==="
    log_info "Branch: $CURRENT_BRANCH"
    log_info "Current version: $CURRENT_VERSION"
    log_info "Workspace: $WORKSPACE_DIR"
    log_info "Dry run: $DRY_RUN"
    log_info "Verbose: $VERBOSE"
    log_info "Output format: $OUTPUT_FORMAT"
    
    # Only add extra newlines in non-JSON mode
    if [[ "$OUTPUT_FORMAT" != "json" ]]; then
        echo ""
    fi
    
    # Extract version components
    extract_version_parts "$CURRENT_VERSION"
    log_info "Version components: MAJOR=$MAJOR, MINOR=$MINOR, PATCH=$PATCH"
    
    # Only add extra newlines in non-JSON mode
    if [[ "$OUTPUT_FORMAT" != "json" ]]; then
        echo ""
    fi
    
    # Calculate next version
    calculate_next_version "$CURRENT_BRANCH"
    log_info "Calculated next version: $NEW_VERSION"
    
    # Only add extra newlines in non-JSON mode
    if [[ "$OUTPUT_FORMAT" != "json" ]]; then
        echo ""
    fi
    
    # Set the version if it's different
    if [[ "$NEW_VERSION" != "$CURRENT_VERSION" ]]; then
        log_info "Version change detected: $CURRENT_VERSION → $NEW_VERSION"
        set_version "$NEW_VERSION"
        
        # Show git diff
        if [[ "$VERBOSE" == "true" ]] && [[ "$OUTPUT_FORMAT" != "json" ]]; then
            echo ""
            log_info "Changes made:"
            git diff "$POM_FILE" || true
        fi
    else
        log_info "No version change needed. Current version is correct for branch: $CURRENT_BRANCH"
    fi
    
    # Output results
    output_results "$CURRENT_VERSION" "$NEW_VERSION" "$CURRENT_BRANCH"
    
    # Only add extra newlines in non-JSON mode
    if [[ "$OUTPUT_FORMAT" != "json" ]]; then
        echo ""
        log_success "=== Version calculation complete ==="
    fi
}

# Run main function
main "$@"
