import os
import unittest
from pathlib import Path
from unittest.mock import patch, MagicMock

from forge_update.types import (
    BuilderType,
    PackageEntry,
    Recipe,
    Source,
    SourceType,
    UpdateConfig,
    UrlSource,
)
from forge_update.recipe import RecipeParser
import forge_update.__main__ as main_mod


class TestUpdateExecution(unittest.TestCase):
    def setUp(self):
        self.parser = RecipeParser(Path("recipes/pkgs"))

    @patch("forge_update.__main__._run_script")
    def test_run_script_called_for_custom_update_script(self, mock_run_script):
        mock_run_script.return_value = 0
        pkg = PackageEntry(
            pname="test-pkg",
            version="1.0.0",
            source=Source(
                type=SourceType.URL, url=UrlSource(url="https://example.com")
            ),
            builder_type=BuilderType.STANDARD,
            update=UpdateConfig(script="./update-all.sh"),
        )
        recipe = Recipe(
            rel_path=Path("recipes/pkgs/test-pkg"),
            abs_path=Path("/tmp/test-pkg/recipe.nix"),
            packages=[pkg],
        )

        with patch("forge_update.__main__.parse_args") as mock_args, patch(
            "forge_update.__main__.RecipeParser.find"
        ) as mock_find, patch("forge_update.__main__.RecipeParser.parse") as mock_parse:
            args = MagicMock()
            args.recipe = ["test-pkg"]
            args.all = False
            args.dry_run = False
            args.commit = False
            args.recipes_root = Path("recipes/pkgs")
            mock_args.return_value = args
            mock_find.return_value = Path("/tmp/test-pkg/recipe.nix")
            mock_parse.return_value = recipe

            main_mod.main()

            mock_run_script.assert_called_once_with("./update-all.sh", recipe, pkg)

    @patch("forge_update.__main__._run_script")
    @patch("forge_update.__main__.VersionDetector.detect")
    def test_skip_when_update_disabled(self, mock_detect, mock_run_script):
        pkg = PackageEntry(
            pname="test-pkg",
            version="1.0.0",
            source=Source(
                type=SourceType.URL, url=UrlSource(url="https://example.com")
            ),
            builder_type=BuilderType.STANDARD,
            update=UpdateConfig(enable=False),
        )
        recipe = Recipe(
            rel_path=Path("recipes/pkgs/test-pkg"),
            abs_path=Path("/tmp/test-pkg/recipe.nix"),
            packages=[pkg],
        )

        with patch("forge_update.__main__.parse_args") as mock_args, patch(
            "forge_update.__main__.RecipeParser.find"
        ) as mock_find, patch("forge_update.__main__.RecipeParser.parse") as mock_parse:
            args = MagicMock()
            args.recipe = ["test-pkg"]
            args.all = False
            args.dry_run = False
            args.commit = False
            args.recipes_root = Path("recipes/pkgs")
            mock_args.return_value = args
            mock_find.return_value = Path("/tmp/test-pkg/recipe.nix")
            mock_parse.return_value = recipe

            main_mod.main()

            mock_detect.assert_not_called()
            mock_run_script.assert_not_called()

    @patch("forge_update.__main__._run_script")
    @patch("forge_update.__main__.VersionDetector.detect")
    def test_pre_script_skip_exit_code_77(self, mock_detect, mock_run_script):
        mock_run_script.return_value = 77  # standard skip code
        pkg = PackageEntry(
            pname="test-pkg",
            version="1.0.0",
            source=Source(
                type=SourceType.URL, url=UrlSource(url="https://example.com")
            ),
            builder_type=BuilderType.STANDARD,
            update=UpdateConfig(pre_script="./pre.sh"),
        )
        recipe = Recipe(
            rel_path=Path("recipes/pkgs/test-pkg"),
            abs_path=Path("/tmp/test-pkg/recipe.nix"),
            packages=[pkg],
        )

        with patch("forge_update.__main__.parse_args") as mock_args, patch(
            "forge_update.__main__.RecipeParser.find"
        ) as mock_find, patch("forge_update.__main__.RecipeParser.parse") as mock_parse:
            args = MagicMock()
            args.recipe = ["test-pkg"]
            args.all = False
            args.dry_run = False
            args.commit = False
            args.recipes_root = Path("recipes/pkgs")
            mock_args.return_value = args
            mock_find.return_value = Path("/tmp/test-pkg/recipe.nix")
            mock_parse.return_value = recipe

            main_mod.main()

            mock_run_script.assert_called_once_with("./pre.sh", recipe, pkg)
            mock_detect.assert_not_called()


if __name__ == "__main__":
    unittest.main()
