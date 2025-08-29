# GitHub Actions Library for QQQ Repositories

A comprehensive, reusable GitHub Actions library that implements GitFlow-based CI/CD pipelines for all QQQ repositories. This library provides standardized workflows for Maven, NPM, and hybrid projects with automatic version management, GPG signing, and publishing to Maven Central and NPM.

> 📚 **Related Documentation**: This library implements the CI/CD strategies documented in the [QQQ Wiki](https://github.com/Kingsrook/qqq.wiki). For detailed information about QQQ architecture, branching strategies, and development workflows, see the [QQQ Wiki Home](https://github.com/Kingsrook/qqq.wiki/wiki/Home).

## 🚀 **Features**

- **🔍 Environment Validation** - Comprehensive secret and configuration validation
- **🌿 GitFlow Support** - Complete GitFlow branching strategy implementation
- **📦 Multi-Platform Publishing** - Maven Central, NPM, and GitHub releases
- **🔐 GPG Signing** - Automatic artifact signing for security
- **🔄 Version Management** - Automatic version bumps based on branch type
- **🧪 Testing & Quality** - Built-in testing, linting, and coverage reporting
- **♻️ Reusable Workflows** - DRY principle implementation across all repos

## 🏗️ **Architecture**

### **Repository Types Supported**
- **Maven-Only** - Java projects publishing to Maven Central
- **NPM-Only** - Node.js projects publishing to npmjs.org
- **Hybrid** - Projects with both Maven and NPM components

### **Branch Strategy**
This library implements the GitFlow branching strategy as documented in the [QQQ Wiki](https://github.com/Kingsrook/qqq.wiki/wiki/Home). For detailed information about the branching strategy, see:

- **`main`** - Production releases (X.Y.Z) → Maven Central + NPM + GitHub releases
- **`develop`** - Development snapshots (X.Y.Z-SNAPSHOT) → Maven Central + NPM
- **`release/*`** - Release candidates (X.Y.0-RC.n) → Maven Central + NPM
- **`hotfix/*`** - Hotfix releases (X.Y.(Z+1)) → Maven Central + NPM + GitHub releases
- **`feature/*`** - Feature development → Build and test only

> 📖 **Learn More**: See [Branching and Versioning](https://github.com/Kingsrook/qqq.wiki/wiki/Branching-and-Versioning) in the QQQ Wiki for detailed explanations of the GitFlow strategy.

## 📁 **Library Structure**

```
.github/
├── actions/                          # Reusable composite actions
│   ├── validate-environment/         # Environment validation action ✅
│   ├── version-management/           # Maven & NPM version management ✅
│   ├── gpg-signing/                  # GPG signing setup and verification ✅
│   ├── maven-publish/                # Maven Central publishing ✅
│   ├── npm-publish/                  # NPM registry publishing ✅
│   ├── github-release/               # GitHub release creation ✅
│   └── git-operations/               # Git operations (tag, commit, push) ✅
├── workflows/                        # Reusable workflows
│   ├── reusable-gitflow-test.yml    # Feature branch testing ✅
│   ├── reusable-gitflow-snapshot.yml # Develop branch snapshots ✅
│   ├── reusable-gitflow-rc.yml      # Release candidates ✅
│   ├── reusable-gitflow-release.yml # Production releases ✅
│   └── reusable-gitflow-hotfix.yml  # Hotfix releases ✅
└── scripts/                          # Utility scripts
    ├── calculate-version.sh         # Maven version management ✅
    ├── sync-npm-version.sh          # NPM version synchronization ✅
    ├── collect-jacoco-reports.sh    # JaCoCo report collection ✅
    └── concatenate-test-output.sh   # Test output aggregation ✅
```

## 🔧 **Usage**

### **1. Basic Repository Setup**

Each repository needs a minimal `.github/workflows/ci.yml`:

```yaml
name: 'CI/CD Pipeline'
on:
  push:
    branches: [main, develop, 'release/**', 'hotfix/**', 'feature/**']
  pull_request:
    branches: [main, develop]

jobs:
  test:
    uses: Kingsrook/github-actions-library/.github/workflows/reusable-gitflow-test@main
    with:
      project-type: 'maven'  # or 'npm' or 'hybrid'
      java-version: '17'
      node-version: '18'
    secrets:
      GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

  snapshot:
    uses: Kingsrook/github-actions-library/.github/workflows/reusable-gitflow-snapshot@main
    with:
      project-type: 'maven'
    secrets:
      GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      GPG_PRIVATE_KEY_B64: ${{ secrets.GPG_PRIVATE_KEY_B64 }}
      GPG_KEYNAME: ${{ secrets.GPG_KEYNAME }}
      GPG_PASSPHRASE: ${{ secrets.GPG_PASSPHRASE }}
      CENTRAL_USERNAME: ${{ secrets.CENTRAL_USERNAME }}
      CENTRAL_PASSWORD: ${{ secrets.CENTRAL_PASSWORD }}
      NPM_TOKEN: ${{ secrets.NPM_TOKEN }}
```

### **2. Required Secrets**

All repositories must have these secrets configured. For information about setting up these secrets in your QQQ repository, see [Developer Onboarding](https://github.com/Kingsrook/qqq.wiki/wiki/Developer-Onboarding) in the QQQ Wiki.

| Secret | Description | Required For |
|--------|-------------|--------------|
| `GITHUB_TOKEN` | GitHub API access | All workflows |
| `GPG_PRIVATE_KEY_B64` | Base64 encoded GPG private key | Publishing workflows |
| `GPG_KEYNAME` | GPG key identifier | Publishing workflows |
| `GPG_PASSPHRASE` | GPG key passphrase | Publishing workflows |
| `CENTRAL_USERNAME` | Maven Central username | Maven publishing |
| `CENTRAL_PASSWORD` | Maven Central password | Maven publishing |
| `NPM_TOKEN` | NPM registry token | NPM publishing |

### **3. Project Configuration**

#### **Maven Projects**
- Must have `pom.xml` with `<revision>` property
- Should include GPG and Maven Central publishing plugins
- Example: See `gha-test-repo/maven-project/pom.xml`
- For Maven configuration best practices, see [Core Modules](https://github.com/Kingsrook/qqq.wiki/wiki/Core-Modules) in the QQQ Wiki

#### **NPM Projects**
- Must have `package.json` with version field
- Should include TypeScript configuration
- Example: See `gha-test-repo/npm-project/package.json`

## 🔄 **Workflow Details**

### **Environment Validation**
Every workflow starts with comprehensive environment validation:
- ✅ GitHub token validation
- ✅ GPG key setup and testing
- ✅ Maven Central connectivity
- ✅ NPM authentication
- ✅ Repository access verification
- ✅ Build tools availability
- ✅ Project file validation

### **Version Management**
Automatic version management based on branch type. This implements the versioning strategy documented in [Semantic Versioning Policy](https://github.com/Kingsrook/qqq.wiki/wiki/Semantic-Versioning-Policy) in the QQQ Wiki:

- **`develop`** → Next minor version (X.Y+1.0-SNAPSHOT)
- **`release/*`** → RC increments (X.Y.0-RC.n)
- **`hotfix/*`** → Patch increments (X.Y.Z+1)
- **`main`** → Stable release (X.Y.Z)

### **Publishing Strategy**
- **Snapshots** → Maven Central snapshots + NPM with `snapshot` tag
- **RCs** → Maven Central releases + NPM with `rc` tag
- **Releases** → Maven Central releases + NPM latest + GitHub releases

## 🚀 **Quick Start**

### **For Maven-Only Repositories**
```yaml
# .github/workflows/ci.yml
jobs:
  test:
    uses: Kingsrook/github-actions-library/.github/workflows/reusable-gitflow-test@main
    with:
      project-type: 'maven'
    secrets:
      GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### **For NPM-Only Repositories**
```yaml
# .github/workflows/ci.yml
jobs:
  test:
    uses: Kingsrook/github-actions-library/.github/workflows/reusable-gitflow-test@main
    with:
      project-type: 'npm'
    secrets:
      GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### **For Hybrid Repositories**
```yaml
# .github/workflows/ci.yml
jobs:
  test:
    uses: Kingsrook/github-actions-library/.github/workflows/reusable-gitflow-test@main
    with:
      project-type: 'hybrid'
    secrets:
      GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## 🔍 **Testing the Library**

The `gha-test-repo` repository contains a complete test implementation:
- Maven project with proper publishing configuration
- NPM project with TypeScript and testing setup
- Complete CI/CD pipeline using this library
- All workflows tested and validated

## 📚 **Documentation**

- **Inline Comments** - All code includes comprehensive inline documentation
- **Workflow Examples** - See `gha-test-repo/.github/workflows/ci.yml`
- **Project Templates** - Maven, NPM, and hybrid project examples
- **Configuration Files** - Maven settings, NPM config, and more

### **Related QQQ Wiki Documentation**
For comprehensive information about the QQQ ecosystem, see these wiki pages:

- **[Home](https://github.com/Kingsrook/qqq.wiki/wiki/Home)** - Overview of the QQQ project
- **[High-Level Architecture](https://github.com/Kingsrook/qqq.wiki/wiki/High-Level-Architecture)** - System architecture and design
- **[Branching and Versioning](https://github.com/Kingsrook/qqq.wiki/wiki/Branching-and-Versioning)** - GitFlow strategy and version management
- **[Semantic Versioning Policy](https://github.com/Kingsrook/qqq.wiki/wiki/Semantic-Versioning-Policy)** - Version numbering conventions
- **[Core Modules](https://github.com/Kingsrook/qqq.wiki/wiki/Core-Modules)** - Maven module structure and configuration
- **[Developer Onboarding](https://github.com/Kingsrook/qqq.wiki/wiki/Developer-Onboarding)** - Setup and configuration guide
- **[Testing](https://github.com/Kingsrook/qqq.wiki/wiki/Testing)** - Testing strategies and best practices
- **[Release Flow](https://github.com/Kingsrook/qqq.wiki/wiki/Release-Flow)** - Release process and procedures

## 🤝 **Contributing**

When contributing to this library:
1. **Document Everything** - Add inline comments for all complex logic
2. **Test Thoroughly** - Use `gha-test-repo` for testing changes
3. **Update README** - Keep this documentation current
4. **Follow Patterns** - Maintain consistency with existing code

For contribution guidelines, see [Contribution Guidelines](https://github.com/Kingsrook/qqq.wiki/wiki/Contribution-Guidelines) in the QQQ Wiki.

## 📞 **Support**

For issues or questions:
1. Check the inline documentation in the code
2. Review the `gha-test-repo` examples
3. Consult the [QQQ Wiki](https://github.com/Kingsrook/qqq.wiki/wiki/Home) for broader context
4. Open an issue in this repository
5. Contact the Kingsrook team

## 🔄 **Migration from CircleCI**

This library replaces the CircleCI configurations used in QQQ repositories. For information about the migration process and differences between CircleCI and GitHub Actions, see:

- **[Building Locally](https://github.com/Kingsrook/qqq.wiki/wiki/Building-Locally)** - Local development setup
- **[Common Errors](https://github.com/Kingsrook/qqq.wiki/wiki/Common-Errors)** - Troubleshooting guide
- **[Feature Development](https://github.com/Kingsrook/qqq.wiki/wiki/Feature-Development)** - Development workflow

---

**Built with ❤️ by the Kingsrook Team**

> 💡 **Tip**: This library is designed to work seamlessly with the existing QQQ ecosystem. For the best experience, familiarize yourself with the [QQQ Wiki](https://github.com/Kingsrook/qqq.wiki/wiki/Home) documentation. 
