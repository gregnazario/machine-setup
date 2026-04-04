# Community Profiles

Curated profiles for common use cases. These extend the built-in profiles
(minimal, full, selfhosted) with role-specific packages.

## Available Profiles

| Profile | Base | Description |
|---------|------|-------------|
| data-science | full | Python, Jupyter, analysis tools |
| devops | full | Containers, orchestration, IaC, cloud CLIs |
| homelab | selfhosted | Docker, monitoring, networking, backup |
| creative | full | Media tools, fonts, writing, diagrams |

## Usage

```bash
# Use directly
./setup.sh --profile community/data-science

# Or create a custom profile that extends one
./setup.sh --create-profile my-ds
# Then edit profiles/my-ds.conf to set: extends = community/data-science
```

## Contributing

To add a new community profile:

1. Create `profiles/community/<name>.conf`
2. Set `extends = minimal`, `full`, or `selfhosted`
3. Add role-specific packages
4. Test with `./setup.sh --validate-profile community/<name>`
5. Submit a PR
