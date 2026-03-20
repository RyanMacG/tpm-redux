# TPM Redux - Current Status & Next Steps

## 📍 Where We Are Now

### Current Version: **v1.2.0** (Stable)
- **Status**: Production ready with 100% TPM feature parity
- **Test Coverage**: 128 passing tests
- **Last Release**: v1.2.0 (parallel operations, lock file support, sourced config support)

### 📝 Version History Context

**v1.1.0**: Added commit display UI (inspired by lazy.nvim)
- Shows commit hashes, messages, and relative times
- Shows all commits between old and new hash
- Includes emoji (📖) in update line

**v1.1.2**: Had commit display feature (from v1.1.0)

**v1.1.3**: Addressed user feedback
- Fixed quoted tilde path handling (#27) - user reported issue with `TMUX_PLUGIN_MANAGER_PATH='~/.tmux/plugins'`
- Improved test isolation
- Fixed test failure in update_all_plugins with multiple plugins

## 🚀 Next Steps

**Focus on v1.3.0** - High-impact features:
- Plugin Search and Discovery (#19) - Hybrid approach (curated list + GitHub API)

---

## 📋 Planned Features (From GitHub Issues)

### High Priority (v1.2.0) 🎯

#### 1. **Parallel Plugin Operations** (#17)
- **Status**: ✅ Shipped in v1.2.0
- **Priority**: High
- **Description**: Run plugin install/update operations in parallel for faster execution
- **Benefits**:
  - Significantly faster install/update times
  - Better UX for users with many plugins
  - Modernizes the tool
- **Implementation**: Use background jobs, maintain progress display, handle errors gracefully
- **Impact**: Most impactful backwards-compatible change (3-5x faster with 5+ plugins)

#### 2. **Lock File Support** (#18)
- **Status**: ✅ Shipped in v1.2.0
- **Priority**: High
- **Description**: Generate and use lock files for reproducible plugin installations
- **Benefits**:
  - Reproducible environments across machines
  - Version pinning for stability
  - Better for teams sharing configurations
- **Implementation**:
  - Generate `tpm.lock` file with exact commit hashes
  - Support `--lock` flag to generate lock file
  - Support `--frozen` flag to install from lock file only
  - Format: JSON or YAML with plugin specs and commit hashes

**v1.2.0**: Shipped! Parallel operations + Lock files

---

### Medium Priority (v1.3.0)

#### 3. **Plugin Search and Discovery** (#19)
- **Status**: Planned - Approach Decided
- **Description**: Hybrid approach (curated list + GitHub API)
- **Target**: v1.3.0

---

### Future Considerations

#### 4. **Plugin Performance Monitoring** (#20)
- Monitor and report on plugin performance impact

#### 5. **Package Manager Integration** (#21)
- Integration with Nix, Homebrew, etc.

#### 6. **Plugin Marketplace/Registry** (#22)
- Centralized registry/marketplace

#### 7. **Enhanced Error Handling** (#23)
- Better error messages and diagnostics

#### 8. **Plugin Subdirectory Support** (#24)
- Support plugins in repository subdirectories

#### 9. **GitHub Authentication Improvements** (#25)
- Better support for private repositories

#### 10. **Plugin Loading Reliability** (#26)
- Improve reliability of plugin loading

---

## 📊 Version Roadmap

### v1.2.0 (Released)
- ✅ **Parallel Plugin Operations** (#17) - Most impactful change
- ✅ **Lock File Support** (#18) - Reproducible installations

### v1.3.0 (Next Release - Medium Priority)
- 🔍 **Plugin Search and Discovery** (#19) - Hybrid approach

### v2.0.0 (Future)
- Potential major features (marketplace, package manager integration)

---

## 🎯 Recommended Next Steps

### Short Term (This Week)
1. **Start planning v1.3.0** - Begin design/implementation of plugin search and discovery (#19)
2. **Review discovery approach** - Finalize hybrid approach (curated list + GitHub API)

### Medium Term (Next Month)
1. **Implement Plugin Search and Discovery** (#19)
   - Hybrid approach: curated list + GitHub API fallback
   - Enables users to discover popular plugins
   - Great for new users

### Long Term (Future)
- Performance monitoring
- Package manager integration
- Plugin marketplace/registry

---

## 📝 Notes

- **Test Coverage**: Currently 128 tests
- **Commit Display**: Currently shows all commits with emoji (from v1.1.0)
- **Backwards Compatibility**: All changes maintain 100% compatibility
- **GitHub Project**: TPM-Redux Kanban board is active
- **Recently Shipped**: Parallel Plugin Operations (#17) and Lock File Support (#18) in v1.2.0

---

## 🔗 Related Resources

- GitHub Issues: https://github.com/RyanMacG/tpm-redux/issues
- GitHub Project: TPM-Redux Kanban (#2)
- Current Release: v1.2.0
- Next Release: v1.3.0 (Plugin search and discovery)
