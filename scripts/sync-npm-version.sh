#!/bin/bash

############################################################################
## sync-npm-version.sh
## NPM Version Synchronization Script for QQQ repositories
## 
## This script updates package.json version based on the current GitFlow 
## branch and versioning policy. Enhanced for GitHub Actions with better
## error handling, logging, and cross-platform compatibility.
##
## Usage: ./sync-npm-version.sh [--dry-run] [--verbose] [--output-format=json|text]
## Output: Updates package.json version and prints the new version
############################################################################

set -e

# Configuration
PACKAGE_JSON="package.json"
DRY_RUN=false
VERBOSE=false
OUTPUT_FORMAT="text"
WORKSPACE_DIR="${GITHUB_WORKSPACE:-$(pwd)}"
SYNC_WITH_MAVEN=false
MAVEN_POM="pom.xml"

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
        --sync-with-maven)
            SYNC_WITH_MAVEN=true
            shift
            ;;
        --maven-pom)
            MAVEN_POM="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [--dry-run] [--verbose] [--output-format=json|text] [--workspace=path] [--sync-with-maven] [--maven-pom=path]"
            echo ""
            echo "Options:"
            echo "  --dry-run           Show what would be done without making changes"
            echo "  --verbose           Enable verbose logging"
            echo "  --output-format     Output format: json or text (default: text)"
            echo "  --workspace         Workspace directory (default: GITHUB_WORKSPACE or current dir)"
            echo "  --sync-with-maven   Sync NPM version with Maven version from pom.xml"
            echo "  --maven-pom         Path to Maven pom.xml (default: pom.xml)"
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

# Validate package.json exists
if [[ ! -f "$PACKAGE_JSON" ]]; then
    log_error "package.json not found in $(pwd)"
    exit 1
fi

# Get current branch and NPM version
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
NPM_VERSION=$(grep '"version"' "$PACKAGE_JSON" | sed 's/.*"version": "//;s/".*//')

if [[ -z "$NPM_VERSION" ]]; then
    log_error "Could not extract version from $PACKAGE_JSON"
    exit 1
fi

log_info "Current branch: $CURRENT_BRANCH"
log_info "Current NPM version: $NPM_VERSION"

# Function to get Maven version if available
get_maven_version() {
    if [[ "$SYNC_WITH_MAVEN" == "true" ]] && [[ -f "$MAVEN_POM" ]]; then
        log_debug "Extracting Maven version from $MAVEN_POM"
        
        if command -v mvn >/dev/null 2>&1; then
            MAVEN_VERSION=$(mvn help:evaluate -Dexpression=project.version -q -DforceStdout 2>/dev/null || echo "")
            if [[ -n "$MAVEN_VERSION" ]]; then
                log_info "Maven version: $MAVEN_VERSION"
                return 0
            fi
        fi
        
        # Fallback to grep if Maven is not available
        MAVEN_VERSION=$(grep '<revision>' "$MAVEN_POM" | sed 's/.*<revision>//;s/<.*//' 2>/dev/null || echo "")
        if [[ -n "$MAVEN_VERSION" ]]; then
            log_info "Maven version (extracted): $MAVEN_VERSION"
            return 0
        fi
    fi
    
    return 1
}

# Function to determine target version based on GitFlow branch
determine_target_version() {
    local branch=$1
    local npm_version=$2
    local maven_version=$3
    
    log_debug "Determining target version for branch: $branch"
    
    # If syncing with Maven, use Maven version as source of truth
    if [[ "$SYNC_WITH_MAVEN" == "true" ]] && [[ -n "$maven_version" ]]; then
        # Remove SNAPSHOT suffix for NPM
        TARGET_VERSION=$(echo "$maven_version" | sed 's/-SNAPSHOT$//')
        log_debug "Syncing with Maven version: $TARGET_VERSION"
        return
    fi
    
    case "$branch" in
        "main")
            # Main branch - should be a release version (e.g., 1.0.0)
            # Extract major.minor from current version
            MAJOR_MINOR=$(echo "$npm_version" | sed 's/\.[0-9]*$//')
            TARGET_VERSION="$MAJOR_MINOR.0"
            log_debug "Main branch: Targeting release version: $TARGET_VERSION"
            ;;
            
        "develop")
            # Develop branch - should be a snapshot version (e.g., 1.0.127-SNAPSHOT)
            # Increment patch version for develop
            MAJOR_MINOR_PATCH=$(echo "$npm_version" | sed 's/-.*//')
            MAJOR_MINOR=$(echo "$MAJOR_MINOR_PATCH" | sed 's/\.[0-9]*$//')
            PATCH=$(echo "$MAJOR_MINOR_PATCH" | sed 's/.*\.//')
            NEW_PATCH=$((PATCH + 1))
            TARGET_VERSION="$MAJOR_MINOR.$NEW_PATCH-SNAPSHOT"
            log_debug "Develop branch: Targeting snapshot version: $TARGET_VERSION"
            ;;
            
        release/*)
            # Release branch - should be a release candidate (e.g., 1.0.0-RC.1)
            RELEASE_VERSION=$(echo "$branch" | sed 's/release\///')
            TARGET_VERSION="$RELEASE_VERSION-RC.1"
            log_debug "Release branch: Targeting RC version: $TARGET_VERSION"
            ;;
            
        hotfix/*)
            # Hotfix branch - should be a patch version (e.g., 1.0.1)
            HOTFIX_VERSION=$(echo "$branch" | sed 's/hotfix\///')
            TARGET_VERSION="$HOTFIX_VERSION"
            log_debug "Hotfix branch: Targeting patch version: $TARGET_VERSION"
            ;;
            
        feature/*|*)
            # Feature branch - should be a snapshot version
            MAJOR_MINOR_PATCH=$(echo "$npm_version" | sed 's/-.*//')
            MAJOR_MINOR=$(echo "$MAJOR_MINOR_PATCH" | sed 's/\.[0-9]*$//')
            PATCH=$(echo "$MAJOR_MINOR_PATCH" | sed 's/.*\.//')
            NEW_PATCH=$((PATCH + 1))
            TARGET_VERSION="$MAJOR_MINOR.$NEW_PATCH-SNAPSHOT"
            log_debug "Feature branch: Targeting snapshot version: $TARGET_VERSION"
            ;;
    esac
}

# Function to update NPM version
update_npm_version() {
    local old_version=$1
    local new_version=$2
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would update package.json version from '$old_version' to '$new_version'"
        log_info "Command: sed -i 's/\"version\": \"$old_version\"/\"version\": \"$new_version\"/' $PACKAGE_JSON"
        return
    fi
    
    log_info "Updating package.json version from '$old_version' to '$new_version'"
    
    # Update version in package.json (cross-platform compatible)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s/\"version\": \"$old_version\"/\"version\": \"$new_version\"/" "$PACKAGE_JSON"
    else
        # Linux and other Unix-like systems
        sed -i "s/\"version\": \"$old_version\"/\"version\": \"$new_version\"/" "$PACKAGE_JSON"
    fi
    
    # Verify the update
    ACTUAL_NPM_VERSION=$(grep '"version"' "$PACKAGE_JSON" | sed 's/.*"version": "//;s/".*//')
    if [[ "$ACTUAL_NPM_VERSION" == "$new_version" ]]; then
        log_success "NPM version successfully updated to: $ACTUAL_NPM_VERSION"
    else
        log_error "NPM version update failed. Expected: $new_version, Got: $ACTUAL_NPM_VERSION"
        exit 1
    fi
}

# Function to output results in specified format
output_results() {
    local old_version=$1
    local new_version=$2
    local branch=$3
    local maven_version=$4
    
    case "$OUTPUT_FORMAT" in
        "json")
            cat << EOF
{
  "success": true,
  "old_npm_version": "$old_version",
  "new_npm_version": "$new_version",
  "branch": "$branch",
  "maven_version": "$maven_version",
  "version_changed": $(if [[ "$old_version" != "$new_version" ]]; then echo "true"; else echo "false"; fi),
  "sync_with_maven": $SYNC_WITH_MAVEN,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
            ;;
        "text"|*)
            if [[ "$old_version" != "$new_version" ]]; then
                log_success "NPM version change: $old_version → $new_version"
            else
                log_info "No NPM version change needed"
            fi
            
            if [[ -n "$maven_version" ]]; then
                log_info "Maven version: $maven_version"
            fi
            ;;
    esac
}

# Main execution
main() {
    log_info "=== QQQ NPM Version Synchronizer (GitHub Actions Enhanced) ==="
    log_info "Branch: $CURRENT_BRANCH"
    log_info "Current NPM version: $NPM_VERSION"
    log_info "Workspace: $WORKSPACE_DIR"
    log_info "Dry run: $DRY_RUN"
    log_info "Verbose: $VERBOSE"
    log_info "Output format: $OUTPUT_FORMAT"
    log_info "Sync with Maven: $SYNC_WITH_MAVEN"
    echo ""
    
    # Get Maven version if requested
    MAVEN_VERSION=""
    if get_maven_version; then
        MAVEN_VERSION="$MAVEN_VERSION"
    fi
    
    # Determine target version
    determine_target_version "$CURRENT_BRANCH" "$NPM_VERSION" "$MAVEN_VERSION"
    
    log_info "Target version: $TARGET_VERSION"
    echo ""
    
    # Check if version change is needed
    if [[ "$NPM_VERSION" == "$TARGET_VERSION" ]]; then
        log_success "Versions are already synchronized"
        output_results "$NPM_VERSION" "$TARGET_VERSION" "$CURRENT_BRANCH" "$MAVEN_VERSION"
        echo ""
        log_success "=== NPM version synchronization complete ==="
        exit 0
    fi
    
    # Update the version
    update_npm_version "$NPM_VERSION" "$TARGET_VERSION"
    
    # Show git diff if verbose
    if [[ "$VERBOSE" == "true" ]]; then
        echo ""
        log_info "Changes made:"
        git diff "$PACKAGE_JSON" || true
    fi
    
    # Output results
    output_results "$NPM_VERSION" "$TARGET_VERSION" "$CURRENT_BRANCH" "$MAVEN_VERSION"
    
    echo ""
    log_success "=== NPM version synchronization complete ==="
    log_info "Previous: $NPM_VERSION"
    log_info "Current:  $TARGET_VERSION"
    log_info "Branch:   $CURRENT_BRANCH"
}

# Run main function
main "$@"
