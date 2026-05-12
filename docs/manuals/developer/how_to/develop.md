# How to develop

Enter a development shell environment:

```bash
nix develop
```

Alternatively, use [`direnv`](https://direnv.net/) to automatically launch the
environment when entering Forge source code directory:

```bash
echo -e "watch_dir flake/develop/\nuse nix" >.envrc

direnv allow
```

## UI development

Launch development server with automatic rebuild on change:

```bash
dev-ui
```

Stop the services by pressing Ctrl-C.

You can supervise those services with:

```bash
systemctl --user status ngi_nix_dev-'*'.service
```

For convenience `systemd-manager-tui` is also provisioned by the development
shell to do the same.
