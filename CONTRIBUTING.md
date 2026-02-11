# Contributing to Multi-DC EVPN Fabric

## Getting Started

Found something you want to improve or add? Great. This guide covers the process.

## Ways to Contribute

### 1. Report Issues
- Found a bug? Document it with:
  - Description of the issue
  - Steps to reproduce
  - Expected vs actual behavior
  - Device type and configuration
  - Relevant logs/output

### 2. Improve Documentation
- Fix typos or clarity issues
- Add troubleshooting scenarios
- Update diagrams
- Write guides or examples

### 3. Add New Features
- New device types or topologies
- Additional test cases
- CloudVision integration
- Segment Routing support
- MLAG leaf pairs

### 4. Optimize Code
- Simplify playbooks
- Improve test coverage
- Enhance error handling
- Add better logging

## Development Workflow

### 1. Fork and Clone
```bash
git clone https://github.com/YOUR_USERNAME/multi-dc-evpn.git
cd multi-dc-evpn
```

### 2. Create Feature Branch
```bash
git checkout -b feature/your-feature-name
# Good branch names:
# - feature/add-mlag-support
# - feature/cloudvision-integration
# - fix/bgp-convergence-issue
# - docs/improve-troubleshooting
```

### 3. Make Changes
```bash
# Edit files
nano ansible/group_vars/dc1.yml
nano tests/test_fabric.py
# etc.
```

### 4. Test Your Changes
```bash
# Deploy topology
cd containerlab
containerlab deploy --topo clab-topology.yml

# Run playbooks
cd ../ansible
ansible-playbook deploy.yml

# Run tests
cd ../tests
pytest test_fabric.py -v

# Verify specific feature
ssh admin@172.20.20.2 "show bgp summary"
```

### 5. Commit Changes
```bash
git add .
git commit -m "Feature: Add MLAG support for leaf pairs

- Implement MLAG configuration in group_vars/dc1_leaves.yml
- Add MLAG validation tests in test_fabric.py
- Update containerlab topology with peer-links
- Document MLAG design in docs/DESIGN.md

Closes #15"
```

### 6. Push and Create PR
```bash
git push origin feature/your-feature-name
# Create Pull Request on GitHub with description
```

## Coding Standards

### YAML Style
```yaml
# Use 2-space indentation
# Keep lines under 100 characters
# Use descriptive variable names

# Good
vlans:
  - vlan_id: 100
    name: tenant1_vlan100
    vni: 10100

# Bad
vlans:
  - id: 100
    nm: t1v100
```

### Ansible Playbooks
```yaml
# Use meaningful task names
- name: Configure BGP on spines
  eos_bgp:
    ...

# Use tags for organization
- name: Deploy configurations
  tags: configure
  eos_interfaces:
    ...

# Use variables over hardcoded values
- name: "Configure Loopback0 with {{ loopback0_ip }}"
  eos_interfaces:
    ...
```

### Python (Tests)
```python
# Use clear test names
def test_dc1_spine1_bgp_established(self):
    """Verify DC1 Spine1 BGP neighbors are established"""
    
# Use assertions with messages
assert "Established" in output, "BGP neighbors not established"

# Group related tests in classes
class TestBGPUnderlay:
    """BGP underlay tests"""
    def test_...(self):
        pass
```

### Comments & Documentation
```python
# Python comments
def connect(self):
    """
    Establish SSH connection to device.
    
    Returns:
        bool: True if successful, False otherwise
    """

# Markdown comments (for complex sections)
# ## Network Design
# This section describes the BGP underlay architecture...
```

## Testing Your Changes

### Unit Tests
```bash
# Test specific class
pytest tests/test_fabric.py::TestBGPUnderlay -v

# Test specific test
pytest tests/test_fabric.py::TestBGPUnderlay::test_dc1_spine1_bgp_established -v
```

### Integration Tests
```bash
# Deploy full topology
containerlab deploy --topo containerlab/clab-topology.yml
ansible-playbook ansible/deploy.yml

# Run all tests
pytest tests/test_fabric.py -v
```

### Manual Validation
```bash
# SSH to device and verify
ssh admin@172.20.20.2 "show bgp summary"
ssh admin@172.20.20.2 "show bgp evpn routes"

# Use containerlab for inspection
containerlab inspect -t containerlab/clab-topology.yml
```

## Before Submitting PR

### Checklist
- [ ] Code follows style guidelines
- [ ] Comments explain complex logic
- [ ] Tests pass locally
- [ ] Documentation is updated
- [ ] Commit messages are clear
- [ ] No hardcoded values
- [ ] Variables are meaningful
- [ ] No sensitive data (passwords, IPs) in commit

### Pre-Submission Review
```bash
# Check what you're committing
git diff

# View commits
git log --oneline -5

# Run linters (if added)
pylint tests/test_fabric.py
yamllint ansible/inventory.yml
```

## Feature Ideas for Contributors

### High Priority
1. **CloudVision Integration**
   - Add CVP device registration
   - Implement config backup
   - Add change control workflow

2. **MLAG Support**
   - Configure peer-links
   - Add MLAG validation tests
   - Handle MLAG failover scenarios

3. **Enhanced Testing**
   - Add stress tests (1000+ MACs)
   - Test failover scenarios
   - Convergence time validation

### Medium Priority
1. **Segment Routing**
   - Implement SR-MPLS
   - Add Traffic Engineering
   - SR-IPv6 support

2. **Multi-Region**
   - Support 3+ datacenters
   - Inter-region policies
   - Multi-region failover

3. **Monitoring Integration**
   - Prometheus metrics export
   - Grafana dashboards
   - Alert definitions

### Lower Priority
1. Documentation improvements
2. Performance optimization
3. Additional device types
4. CI/CD pipeline enhancements

## Directory Structure for New Features

```
For a new feature "feature-name":

ansible/
├── group_vars/
│   ├── dc1_feature_name.yml      # DC1 specific config
│   └── dc2_feature_name.yml      # DC2 specific config
└── host_vars/
    └── dc{n}-device.yml          # Device specific config

tests/
└── test_feature_name.py          # Feature tests

docs/
├── FEATURE_NAME.md               # Feature documentation
└── DESIGN.md                     # Update design section

containerlab/
└── clab-topology.yml             # Update if topology changes
```

## Documentation Requirements

For each feature, please update:

1. **README.md** - Add feature to features list
2. **DESIGN.md** - Add design section if architectural
3. **TROUBLESHOOTING.md** - Add troubleshooting section
4. **docs/FEATURE_NAME.md** - Create detailed guide (if complex)

Example documentation structure:
```markdown
# Feature Name

## Overview
Brief description of feature

## Architecture
How it works

## Configuration
Example configuration

## Validation
How to verify it's working

## Troubleshooting
Common issues and solutions
```

## Git Best Practices

### Commit Messages
```
Good:
  "Feature: Add MLAG configuration for leaf pairs"
  "Fix: Correct VXLAN tunnel source IP"
  "Docs: Update design guide with MLAG section"

Bad:
  "Update files"
  "Fix stuff"
  "Changes"

Format:
  [Type]: [Description]
  
  [Optional body with more details]
  
  Closes #123
```

### Types
- `Feature:` New functionality
- `Fix:` Bug fix
- `Docs:` Documentation only
- `Refactor:` Code restructuring
- `Test:` Test additions/changes
- `Chore:` Maintenance tasks

## Communication

### Questions?
- Open an issue for discussion
- Add label: `question`
- Describe what you're trying to do

### Found a bug?
- Create an issue
- Add label: `bug`
- Include reproduction steps

### Have ideas?
- Start a discussion
- Add label: `enhancement`
- Describe the use case

## Code Review Process

1. **Automated Checks**
   - Tests must pass
   - No merge conflicts
   - Code style validation

2. **Manual Review**
   - Code quality assessment
   - Architecture review
   - Documentation verification

3. **Approval**
   - One maintainer approval required
   - Address any feedback
   - Update PR if needed

4. **Merge**
   - Squash commits for clarity (optional)
   - Delete feature branch
   - Close related issues

## Release Process

Versions follow semantic versioning: `MAJOR.MINOR.PATCH`

- Patch: Bug fixes
- Minor: New features
- Major: Breaking changes

```bash
# To create a release:
1. Update version in README.md
2. Update CHANGELOG.md
3. Create git tag: git tag v1.2.0
4. Push tag: git push origin v1.2.0
5. Create GitHub release with notes
```

## Code Examples

### Adding a Test
```python
# tests/test_fabric.py
class TestNewFeature:
    """Tests for new feature"""
    
    def test_feature_enabled(self, dc1_spine1):
        """Verify new feature is enabled"""
        output = dc1_spine1.send_command("show feature-name summary")
        assert "enabled" in output.lower(), "Feature not enabled"
        
    def test_feature_functionality(self, dc1_spine1):
        """Verify feature functions correctly"""
        output = dc1_spine1.send_command("show feature-name details")
        assert "Operational" in output, "Feature not operational"
```

### Adding Configuration
```yaml
# ansible/group_vars/dc1.yml
# Add new variable
feature_enabled: true
feature_config:
  parameter1: value1
  parameter2: value2
```

### Adding Documentation
```markdown
# FEATURE_NAME.md

## Configuration

To enable feature:

```yaml
# In group_vars/dc1.yml
feature_enabled: true
```

To verify:

```bash
ssh admin@172.20.20.2 "show feature-name"
```
```

## Support

- **Issues:** Use GitHub issues for bugs/questions
- **Discussions:** Use GitHub discussions for ideas
- **Security:** Email security@example.com for vulnerabilities

## License

By contributing, you agree your code will be licensed under the same MIT license as the project.

## Recognition

Contributors will be recognized in:
- README.md contributors section
- Release notes
- Project documentation

Thank you for contributing! 🎉

---

**Guidelines Version:** 1.0  
**Last Updated:** February 2026
