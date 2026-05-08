# NGI Forge

```{toctree}
:hidden: true

manuals/user/index.md
manuals/contributor/index.md
manuals/developer/index.md
announcements/index.md
```

Welcome to NGI Forge, the software distribution system for projects funded via [Next Generation Internet (NGI)](https://www.ngi.eu/).

::::{grid} 2
:::{grid-item-card} User Manual
:link: manuals/user/prerequisites
:link-type: doc
:text-align: center

How to use NGI Forge applications
:::

:::{grid-item-card} Contributor Manual
:link: manuals/contributor/how_to/package_recipe
:link-type: doc
:text-align: center

How to create package and application recipes
:::
::::

::::{grid} 2
:::{grid-item-card} Developer Manual
:link: manuals/developer/how_to/develop
:link-type: doc
:text-align: center

How to develop NGI Forge
:::

:::{grid-item-card} Announcements
:link: announcements/index
:link-type: doc
:text-align: center

Release notes and project news
:::
::::

## Quick Start

1. Visit the [NGI Forge web UI](https://ngi-nix.github.io/forge) in your browser.
2. Browse the list of available applications.
3. Choose an application and click the **Run** button.
4. Follow the instructions to launch the application in your preferred runtime:
   - **Shell** — run CLI or GUI programs directly in your terminal
   - **Container** — run application services in OCI containers using Podman
   - **NixOS VM** — run application services in an isolated NixOS virtual machine

Before running applications, make sure the [prerequisites](manuals/user/prerequisites.md) are met.
