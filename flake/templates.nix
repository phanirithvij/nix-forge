{
  flake.templates = {
    consumer = {
      path = ../templates/consumer;
      description = "Template for using and extending an NGI Forge instance";
    };
    provider = {
      path = ../templates/provider;
      description = "Template for self hosting your own NGI Forge instance";
    };
    vm = {
      path = ../templates/vm;
      description = "Stateless NixOS VM for testing modules and forge services";
    };
  };
}
