# Usage:
#   nix-shell --run 'dev-ui'
{
  callPackage,
}:
(callPackage ../forge-ui {
  mockBackend = "true";
  name = "dev-ui";
  description = "launch Forge development server";
})
