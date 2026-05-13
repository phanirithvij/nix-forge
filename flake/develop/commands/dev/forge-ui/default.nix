# Usage:
#   nix-shell --run 'forge-ui'
{
  replaceVarsWith,
  writeShellApplication,

  coreutils,
  gitMinimal,
  python3,
  runtimeShell,
  systemd,

  mockBackend ? "false",
  defaultListenPort ? 3000,
  numApps ? 20,
  numPackages ? 20,
  name ? "forge-ui",
  description ? "launch local Forge server",
}:
let
  substitutedScript = replaceVarsWith {
    name = "forge-ui-inner";
    isExecutable = true;
    dir = "bin";
    src = ./ui.sh;
    replacements = {
      inherit
        runtimeShell
        mockBackend
        defaultListenPort
        numApps
        numPackages
        ;
    };
  };
in
writeShellApplication {
  inherit name;
  runtimeInputs = [
    coreutils
    gitMinimal
    python3
    systemd
  ];
  text = ''
    exec ${substitutedScript}/bin/forge-ui-inner "$@"
  '';
  meta = { inherit description; };
}
