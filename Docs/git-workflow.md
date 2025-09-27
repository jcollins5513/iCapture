# Git Workflow for iCapture

## Repository Setup ✅

The iCapture project is now set up with Git version control:

- **Repository**: Initialized with proper `.gitignore` for iOS development
- **Initial Commit**: Contains complete Milestone 1 & 2 implementation
- **Pre-commit Hook**: Automatically runs linting and build checks
- **Commit Template**: Standardized commit message format

## Workflow Guidelines

### Branch Strategy
- **main**: Stable, production-ready code
- **feature/milestone-X**: Feature branches for each milestone
- **hotfix/**: Critical bug fixes

### Commit Message Format
```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes
- `refactor`: Code refactoring
- `test`: Adding/updating tests
- `chore`: Maintenance tasks

**Examples:**
```
feat(milestone2): Add draggable frame box functionality
fix(camera): Resolve AVFoundation concurrency warnings
docs(readme): Update build instructions
```

### Pre-commit Checks

Every commit automatically runs:
1. SwiftLint (code quality checks)
2. Build validation (`xcodebuild`)

If checks fail, the commit is rejected.

### Development Workflow

1. **Before starting work:**
   ```bash
   git pull origin main
   git checkout -b feature/milestone-X
   ```

2. **During development:**
   ```bash
   git add .
   git commit -m "feat(milestone3): Implement ROI occupancy detection"
   ```

3. **Before pushing:**
   ```bash
   git push origin feature/milestone-X
   ```

4. **After milestone completion:**
   ```bash
   git checkout main
   git merge feature/milestone-X
   git push origin main
   ```

### File Organization

**Always commit:**
- Source code (`.swift` files)
- Configuration files (`.yml`, `.json`)
- Documentation (`.md` files)
- Scripts (`.sh` files)
- Project files (`.pbxproj`, `.xcworkspace`)

**Never commit:**
- User-specific files (`xcuserdata/`)
- Build artifacts (`DerivedData/`, `build/`)
- Generated files
- Test media files
- Personal settings

### Quality Gates

- ✅ All code must pass SwiftLint
- ✅ All builds must succeed
- ✅ All tests must pass (when implemented)
- ✅ Documentation must be updated for new features

## Current Status

- **Repository**: `f8dd924` - Initial commit with Milestones 1 & 2 complete
- **Branch**: `main`
- **Next**: Ready for Milestone 3 development

## Useful Commands

```bash
# Check status
git status

# View commit history
git log --oneline

# View changes
git diff

# Reset to last commit (discard changes)
git checkout -- .

# Create feature branch
git checkout -b feature/milestone3

# Switch branches
git checkout main

# Merge feature branch
git merge feature/milestone3

# Delete feature branch
git branch -d feature/milestone3
```

## Integration with Project Rules

This Git workflow enforces the project's core principles:
- **Quality**: Pre-commit hooks ensure code quality
- **Consistency**: Commit message templates maintain standards
- **Traceability**: Clear commit history tracks progress
- **Collaboration**: Branch strategy supports team development
