"""forge-update: Update forge package recipes to latest upstream versions."""

import argparse
import os
import shlex
import subprocess
import sys
from collections.abc import Iterator
from contextlib import contextmanager
from pathlib import Path

from colorama import Fore, Style
from colorama import init as colorama_init

from .builder import BuilderHashUpdater
from .errors import ForgeUpdateError
from .hasher import HashPrefetcher
from .recipe import RecipeParser, RecipeWriter
from .types import PackageEntry, Recipe
from .version import VersionDetector, VersionResult

colorama_init()


def style(text: str, *parts: str) -> str:
    if not sys.stdout.isatty() or os.environ.get("NO_COLOR"):
        return text
    return "".join(parts) + text + Style.RESET_ALL


def _print_changes(writer: RecipeWriter, before: int) -> None:
    for field, old, new in writer.pending_changes[before:]:
        print(f"  {style(field, Style.BRIGHT)}")
        print(f"    {style(f'-{old}', Fore.RED)}")
        print(f"    {style(f'+{new}', Fore.GREEN)}")


@contextmanager
def _progress(label: str) -> Iterator[None]:
    print(f"  {style(label, Style.BRIGHT)} (in progress)", end="\r", flush=True)
    try:
        yield
    finally:
        _ = sys.stdout.write("\r\033[K")


def _commit_recipe(recipe: Recipe, pkg: PackageEntry, version_str: str) -> None:
    msg = (
        f"recipes({pkg.pname}): {pkg.version} -> {version_str}"
        if version_str != pkg.version
        else f"recipes({pkg.pname}): update"
    )
    _ = subprocess.run(
        ["git", "add", str(recipe.abs_path.parent)], check=True, capture_output=True
    )
    diff = subprocess.run(["git", "diff", "--cached", "--quiet"])
    if diff.returncode != 0:
        _ = subprocess.run(
            ["git", "commit", "-m", msg], check=True, capture_output=True
        )
        print(f"  {style('committed', Style.DIM)}")
    else:
        print(f"  {style('nothing to commit', Style.DIM)}")


def _run_script(script_str: str, recipe: Recipe, pkg: PackageEntry) -> int:
    """Execute a hook or update script in recipe directory."""
    recipe_dir = recipe.abs_path.parent
    cmd = shlex.split(script_str)
    if cmd[0].startswith("./") or (recipe_dir / cmd[0]).exists():
        script_file = (recipe_dir / cmd[0]).resolve()
        if script_file.exists():
            cmd[0] = str(script_file)
            try:
                script_file.chmod(script_file.stat().st_mode | 0o111)
            except OSError:
                pass

    env = os.environ.copy()
    env["FORGE_PACKAGE_NAME"] = pkg.pname
    env["FORGE_PACKAGE_VERSION"] = pkg.version
    env["FORGE_RECIPE_PATH"] = str(recipe.abs_path)
    env["FORGE_RECIPE_DIR"] = str(recipe_dir)

    res = subprocess.run(cmd, cwd=str(recipe_dir), env=env)
    return res.returncode


class Args(argparse.Namespace):
    recipe: list[str] = []
    all: bool = False
    version: str | None = None
    dry_run: bool = False
    commit: bool = False
    skip_prefetch: bool = False
    prefetch_timeout: int = 180
    recipes_root: Path = Path("recipes/pkgs")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="forge-update",
        description="Update forge package recipes to latest upstream versions",
    )

    _ = parser.add_argument("recipe", nargs="*", default=[], metavar="RECIPE")
    _ = parser.add_argument(
        "--all",
        action="store_true",
        help="Update all recipes in --recipes-root",
    )
    _ = parser.add_argument("--version")
    _ = parser.add_argument("--dry-run", action="store_true")
    _ = parser.add_argument(
        "--commit",
        action=argparse.BooleanOptionalAction,
        default=False,
        help="Commit recipe changes to git",
    )
    _ = parser.add_argument("--skip-prefetch", action="store_true")
    _ = parser.add_argument(
        "--prefetch-timeout",
        type=int,
        default=180,
        help="Timeout in seconds for each hash prefetch (default: 180)",
    )
    _ = parser.add_argument(
        "--recipes-root",
        type=Path,
        default=Path("recipes/pkgs"),
    )

    return parser


def parse_args(argv: list[str] | None = None) -> Args:
    return build_parser().parse_args(argv, namespace=Args())


def main() -> None:
    args = parse_args()

    if not args.recipe and not args.all:
        build_parser().print_help()
        sys.exit(0)

    if args.all and args.recipe:
        build_parser().error("--all cannot be used with recipe names")

    names = (
        sorted(p.name for p in args.recipes_root.iterdir()) if args.all else args.recipe
    )

    parser = RecipeParser(args.recipes_root)
    detector = VersionDetector()
    prefetcher = HashPrefetcher(timeout=args.prefetch_timeout)
    builder_hash = BuilderHashUpdater(dry_run=args.dry_run)

    for i, name in enumerate(names):
        if i > 0:
            print()
        try:
            path = parser.find(name)
            recipe = parser.parse(path)
            pkg = recipe.packages[0]
            writer = RecipeWriter(dry_run=args.dry_run)

            # 1. Check if updates are disabled
            if not pkg.update.enable:
                print(style(name, Fore.YELLOW + Style.BRIGHT))
                print(f"  {style('skipped (update disabled)', Fore.YELLOW)}")
                continue

            # 2. Check if a full custom updateScript is specified (full override)
            if pkg.update.script:
                print(style(name, Fore.YELLOW + Style.BRIGHT))
                print(
                    f"  {style('running updateScript: ' + pkg.update.script, Style.DIM)}"
                )
                if not args.dry_run:
                    code = _run_script(pkg.update.script, recipe, pkg)
                    if code == 77:
                        print(
                            f"  {style('skipped by updateScript (exit 77)', Fore.YELLOW)}"
                        )
                        continue
                    if code != 0:
                        raise ForgeUpdateError(
                            f"updateScript failed with exit code {code}"
                        )

                    new_version = pkg.version
                    try:
                        re_parsed = parser.parse(path)
                        new_version = re_parsed.packages[0].version
                    except Exception:
                        pass

                    if args.commit:
                        _commit_recipe(recipe, pkg, new_version)
                continue

            # 3. Check preUpdateScript hook
            if pkg.update.pre_script:
                print(style(name, Fore.YELLOW + Style.BRIGHT))
                print(f"  {style('running preUpdateScript', Style.DIM)}")
                if not args.dry_run:
                    code = _run_script(pkg.update.pre_script, recipe, pkg)
                    if code == 77:
                        print(
                            f"  {style('skipped by preUpdateScript (exit 77)', Fore.YELLOW)}"
                        )
                        continue
                    if code != 0:
                        raise ForgeUpdateError(
                            f"preUpdateScript failed with exit code {code}"
                        )

            if args.version:
                result = VersionResult(version=args.version, rev="")
            else:
                result = detector.detect(recipe)

            g = pkg.source.git
            current_rev = g.rev if g else ""
            rev_changed = bool(result.rev) and result.rev != current_rev
            version_changed = pkg.version != result.version

            if not pkg.update.pre_script:
                print(style(name, Fore.YELLOW + Style.BRIGHT))

            if not version_changed and not rev_changed:
                print(f"  {style('already at ' + pkg.version, Fore.YELLOW)}")
                continue

            writer.update_version(recipe, pkg.pname, result.version)
            _print_changes(writer, 0)

            if result.rev:
                before = len(writer.pending_changes)
                writer.update_git_rev(recipe, pkg.pname, result.rev)
                _print_changes(writer, before)

            should_prefetch = (
                g is not None
                and result.rev
                and not args.dry_run
                and not args.skip_prefetch
            )
            if should_prefetch:
                assert g is not None
                before = len(writer.pending_changes)
                with _progress("source.hash"):
                    new_hash = prefetcher.prefetch_git(
                        g.remote_url, result.rev, g.submodules
                    )
                writer.update_source_hash(recipe, pkg.pname, new_hash)
                _print_changes(writer, before)

                field = builder_hash.field_name(pkg)
                if field:
                    before = len(writer.pending_changes)
                    with _progress(field):
                        builder_hash.update(recipe, writer, pkg)
                    _print_changes(writer, before)

            writer.apply(recipe)

            # 4. Check postUpdateScript hook
            if pkg.update.post_script and not args.dry_run:
                print(f"  {style('running postUpdateScript', Style.DIM)}")
                code = _run_script(pkg.update.post_script, recipe, pkg)
                if code != 0:
                    raise ForgeUpdateError(
                        f"postUpdateScript failed with exit code {code}"
                    )

            if args.commit and not args.dry_run:
                _commit_recipe(recipe, pkg, result.version)
        except ForgeUpdateError as e:
            print(style(name, Fore.YELLOW + Style.BRIGHT))
            print(f"  {style(str(e), Fore.RED)}")
            continue


if __name__ == "__main__":
    main()
