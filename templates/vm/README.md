# NGI Forge Dev VM

A fast, stateless NixOS VM for the NGI team to test NixOS modules and Forge services.

## Setup

Check out [`personal.nix`](./personal.nix) to tweak personal settings before running.

## Usage

Build and start the VM:

```bash
nix build
./result/bin/run-nixos-vm
```

Features:

- **Headless:** No GUI by default.
- **NGI Forge ready:** Easily import `ngi-nix-forge` apps as NixOS modules.
- **Stateless:** No persistent disk. Changes disappear on restart.
- **Shared `/etc/nixos`:** The host's current directory is mounted inside the VM.
- **Shared `/nix/store`:** Fast boots, no duplicate downloads.
- **History:** Shell history is saved to [`history`](./history) on the host.
- **Tools:** Neovim, git, and auto-login out of the box.

Apply changes on the fly without restarting:

```bash
vm-switch
```

Update inputs:

```bash
nix flake update
```

## Local Development

Test local `nixpkgs` or `forge` changes using `--override-input`:

```bash
nix build --override-input nixpkgs path:/path/to/nixpkgs
nix build --override-input ngi-forge path:/path/to/forge
```

Or just change the URLs directly in `flake.nix`.

## Credits

Based on the [nix-hour](https://github.com/tweag/nix-hour) template by [Tweag](https://github.com/tweag) and [@infinisil](https://github.com/infinisil).
