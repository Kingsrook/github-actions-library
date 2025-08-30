# GitHub Actions Library for QQQ Repositories

This repository contains reusable GitHub Actions workflows and composite actions for the QQQ project ecosystem. It implements the DRY (Don't Repeat Yourself) principle by centralizing all CI/CD logic in one place.

## 🚀 Quick Start

### For Publishing Branches (main, release/*, develop, hotfix/*)
```yaml
- uses: Kingsrook/github-actions-library/.github/workflows/reusable-gitflow-publish@main
  with:
    project-type: 'hybrid'        # maven, npm, or hybrid
    maven-working-directory: 'maven-project'
    npm-working-directory: 'npm-project'
```

### For Feature Branches (feature/*, any other branch)
```yaml
- uses: Kingsrook/github-actions-library/.github/workflows/reusable-gitflow-test@main
  with:
    project-type: 'hybrid'
    maven-working-directory: 'maven-project'
    npm-working-directory: 'npm-project'
```

## 📋 Available Workflows

### 1. `reusable-gitflow-publish.yml` - Publishing Workflow
**Use on**: `main`, `release/*`, `develop`, `hotfix/*` branches

**What it does**:
- ✅ Environment validation (secrets, GPG, Maven Central, NPM)
- ✅ Intelligent version management using `calculate-version.sh`
- ✅ Build and test projects
- ✅ Publish to Maven Central and NPM
- ✅ Commit and push version changes

**Version Strategy**:
- `develop` → Creates `X.Y.Z-SNAPSHOT` versions
- `release/*` → Creates `X.Y.Z-RC.N` versions
- `main` → Creates stable `X.Y.Z` versions
- `hotfix/*` → Creates patch `X.Y.Z+1` versions

### 2. `reusable-gitflow-test.yml` - Testing Workflow
**Use on**: `feature/*` and any other branches

**What it does**:
- ✅ Environment validation (no GPG required)
- ✅ Build and test projects
- ✅ Collect test results and coverage reports
- ✅ No publishing or version changes

## 🔧 Composite Actions

### Core Actions
- **`validate-environment`** - Validates required secrets and configurations
- **`gpg-signing`** - Sets up GPG environment for artifact signing
- **`version-management`** - Manages version calculation and updates using calculate-version.sh
- **`build-test`** - Builds and tests Maven and NPM projects
- **`git-operations`** - Handles Git commit and push operations

## 📚 Usage Examples

### Maven-Only Project
```yaml
name: 'CI/CD Pipeline'

on:
  push:
    branches: [ main, develop, release/*, hotfix/*, feature/* ]
  pull_request:
    branches: [ main, develop ]

jobs:
  # Publishing branches
  publish:
    if: contains(github.ref, 'main') || contains(github.ref, 'develop') || contains(github.ref, 'release/') || contains(github.ref, 'hotfix/')
    uses: Kingsrook/github-actions-library/.github/workflows/reusable-gitflow-publish@main
    with:
      project-type: 'maven'
      java-version: '17'
      maven-working-directory: '.'
    secrets:
      GPG_PRIVATE_KEY_B64: ${{ secrets.GPG_PRIVATE_KEY_B64 }}
      GPG_KEYNAME: ${{ secrets.GPG_KEYNAME }}
      GPG_PASSPHRASE: ${{ secrets.GPG_PASSPHRASE }}
      CENTRAL_USERNAME: ${{ secrets.CENTRAL_USERNAME }}
      CENTRAL_PASSWORD: ${{ secrets.CENTRAL_PASSWORD }}

  # Feature branches
  test:
    if: contains(github.ref, 'feature/') || !contains(github.ref, 'main') && !contains(github.ref, 'develop') && !contains(github.ref, 'release/') && !contains(github.ref, 'hotfix/')
    uses: Kingsrook/github-actions-library/.github/workflows/reusable-gitflow-test@main
    with:
      project-type: 'maven'
      java-version: '17'
      maven-working-directory: '.'
```

### Hybrid Project (Maven + NPM)
```yaml
name: 'CI/CD Pipeline'

on:
  push:
    branches: [ main, develop, release/*, hotfix/*, feature/* ]
  pull_request:
    branches: [ main, develop ]

jobs:
  # Publishing branches
  publish:
    if: contains(github.ref, 'main') || contains(github.ref, 'develop') || contains(github.ref, 'release/') || contains(github.ref, 'hotfix/')
    uses: Kingsrook/github-actions-library/.github/workflows/reusable-gitflow-publish@main
    with:
      project-type: 'hybrid'
      java-version: '17'
      node-version: '18'
      maven-working-directory: 'backend'
      npm-working-directory: 'frontend'
    secrets:
      GPG_PRIVATE_KEY_B64: ${{ secrets.GPG_PRIVATE_KEY_B64 }}
      GPG_KEYNAME: ${{ secrets.GPG_KEYNAME }}
      GPG_PASSPHRASE: ${{ secrets.GPG_PASSPHRASE }}
      CENTRAL_USERNAME: ${{ secrets.CENTRAL_USERNAME }}
      CENTRAL_PASSWORD: ${{ secrets.CENTRAL_PASSWORD }}
      NPM_TOKEN: ${{ secrets.NPM_TOKEN }}

  # Feature branches
  test:
    if: contains(github.ref, 'feature/') || !contains(github.ref, 'main') && !contains(github.ref, 'develop') && !contains(github.ref, 'release/') && !contains(github.ref, 'hotfix/')
    uses: Kingsrook/github-actions-library/.github/workflows/reusable-gitflow-test@main
    with:
      project-type: 'hybrid'
      java-version: '17'
      node-version: '18'
      maven-working-directory: 'backend'
      npm-working-directory: 'frontend'
```

## 🔐 Required Secrets

### For Publishing Workflows
- `GPG_PRIVATE_KEY_B64` - Base64 encoded GPG private key
- `GPG_KEYNAME` - GPG key identifier (email or key ID)
- `GPG_PASSPHRASE` - GPG key passphrase
- `CENTRAL_USERNAME` - Sonatype OSSRH username
- `CENTRAL_PASSWORD` - Sonatype OSSRH password
- `NPM_TOKEN` - NPM authentication token

### For Testing Workflows
- No secrets required (unless your tests need them)

## 🧠 Version Management

The publishing workflow uses the `calculate-version.sh` script to intelligently determine the next version based on:

- **Current branch name** (develop, release/*, main, hotfix/*)
- **Current version in pom.xml**
- **GitFlow conventions**

The script automatically:
- Detects branch type from Git
- Calculates appropriate next version
- Updates pom.xml with new version
- Handles SNAPSHOT, RC, and stable versions

## 🏗️ Architecture

### DRY Principle Implementation
- **Composite Actions**: Reusable building blocks for common operations
- **Unified Workflows**: Two workflows handle all GitFlow scenarios
- **Intelligent Versioning**: Script-based version management
- **Automatic Publishing**: Maven/NPM handle destinations based on version suffixes

### Workflow Structure
```
reusable-gitflow-publish.yml (Publishing)
├── Environment Validation
├── Version Management (calculate-version.sh)
├── Build and Test
├── Publish Artifacts
└── Git Operations

reusable-gitflow-test.yml (Testing)
├── Environment Validation
├── Build and Test
└── Artifact Collection
```

## 🔄 Migration from CircleCI

To migrate from CircleCI to this library:

1. **Remove CircleCI config**: Delete `.circleci/config.yml`
2. **Add GitHub Actions**: Create `.github/workflows/ci.yml` using the examples above
3. **Configure secrets**: Add required secrets to your GitHub repository
4. **Test**: Push to a feature branch to test the testing workflow
5. **Deploy**: Push to develop/main to test the publishing workflow

## 📖 Documentation

- **QQQ Wiki**: [Link to QQQ wiki documentation]
- **GitFlow Guide**: [Link to GitFlow documentation]
- **Maven Central Publishing**: [Link to Maven Central guide]
- **NPM Publishing**: [Link to NPM publishing guide]

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

[Your license information here] 
