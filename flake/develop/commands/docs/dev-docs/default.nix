{
  gnumake,
  writeShellApplication,
}:

writeShellApplication {
  name = "dev-docs";
  runtimeInputs = [ gnumake ];
  text = ''
    make -C "$(git rev-parse --show-toplevel)/docs" html
  '';
  meta.description = "build HTML documentation";
}
