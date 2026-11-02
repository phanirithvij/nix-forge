# How to update a package recipe

The Forge provides a script for updating package recipes to the latest upstream versions.

To access it, start by entering the development environment:

```bash
nix develop

# or
nix-shell
```

Then, to see all available options run:

```bash
forge-update --help
```

::: {note}
Update script can also be launched without entering the development environment:

```bash
nix develop --command forge-update

# or
nix-shell --run forge-update
```

:::

## Usage Examples

Update individual recipes:

```bash
forge-update tau-tower
```

Update multiple recipes:

```bash
forge-update tau-tower tau-radio
```

Update all recipes:

```bash
forge-update --all
```

Update recipes and commit changes:

```bash
forge-update tau-radio --commit
```

Update recipes, but don't prefetch hashes or modify recipe files:

```bash
forge-update tau-radio --dry-run
```

## Custom Update Scripts and Hooks

Package recipes can customize the update process using hooks or a dedicated update script in their `recipe.nix`:

### Post-Update Hook (`update.postScript`)

Runs after `forge-update` detects a new upstream version and updates `version` and `source.hash`. Ideal for packages requiring auxiliary lockfile updates (such as `yarn.lock`) or regenerating assets:

```nix
pkgs.my-package = {
  version = "1.0.0";
  # ...
  update.postScript = ./update.sh;
  # Or: postUpdateScript = ./update.sh;
};
```

### Pre-Update Hook (`update.preScript`)

Runs before `forge-update` checks upstream versions or hashes. If the script exits with status code `77` (standard skip code), `forge-update` will cleanly skip updating this package:

```nix
pkgs.my-package = {
  # ...
  update.preScript = ./check-preconditions.sh;
  # Or: preUpdateScript = ./check-preconditions.sh;
};
```

### Full Custom Update Script (`update.script`)

Completely overrides `forge-update`'s built-in version detection and hash updating, delegating the update entirely to the custom script (similar to Nixpkgs' `passthru.updateScript`):

```nix
pkgs.my-package = {
  # ...
  update.script = ./full-update.sh;
  # Or: updateScript = ./full-update.sh;
};
```

### Disabling Updates (`update.enable = false` or `skipUpdate = true`)

To pin a package or prevent automated updates from modifying it during `forge-update --all`:

```nix
pkgs.my-package = {
  # ...
  update.enable = false;
  # Or: skipUpdate = true;
};
```
