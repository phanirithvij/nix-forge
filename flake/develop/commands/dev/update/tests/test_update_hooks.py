import unittest
from pathlib import Path
from unittest.mock import patch, MagicMock

from forge_update.types import UpdateConfig
from forge_update.recipe import RecipeParser


class TestUpdateHooks(unittest.TestCase):
    def setUp(self):
        self.parser = RecipeParser(Path("recipes/pkgs"))

    def test_parse_update_block_nested(self):
        text = """
        pkgs.foo = {
          version = "1.0.0";
          source.url = "https://example.com/foo.tar.gz";
          source.hash = "sha256-AAAA=";
          build.builders.standard.enable = true;
          update = {
            enable = false;
            script = ./custom.sh;
            preScript = ./pre.sh;
            postScript = ./post.sh;
          };
        }
        """
        cfg = self.parser._parse_update(text)
        self.assertFalse(cfg.enable)
        self.assertEqual(cfg.script, "./custom.sh")
        self.assertEqual(cfg.pre_script, "./pre.sh")
        self.assertEqual(cfg.post_script, "./post.sh")

    def test_parse_update_flat_syntax(self):
        text = """
        pkgs.bar = {
          version = "2.0.0";
          source.url = "https://example.com/bar.tar.gz";
          source.hash = "sha256-BBBB=";
          build.builders.standard.enable = true;
          skipUpdate = true;
          updateScript = "./run-update.sh";
          preUpdateScript = "./pre.sh";
          postUpdateScript = "./post.sh";
        }
        """
        cfg = self.parser._parse_update(text)
        self.assertFalse(cfg.enable)
        self.assertEqual(cfg.script, "./run-update.sh")
        self.assertEqual(cfg.pre_script, "./pre.sh")
        self.assertEqual(cfg.post_script, "./post.sh")

    def test_parse_update_enable_explicit(self):
        text = """
        pkgs.baz = {
          version = "3.0.0";
          source.url = "https://example.com/baz.tar.gz";
          source.hash = "sha256-CCCC=";
          build.builders.standard.enable = true;
          update.enable = false;
          postUpdateScript = ./update-deps.sh;
        }
        """
        cfg = self.parser._parse_update(text)
        self.assertFalse(cfg.enable)
        self.assertEqual(cfg.post_script, "./update-deps.sh")

    def test_parse_mustang_recipe(self):
        mustang_path = Path("recipes/pkgs/mustang/recipe.nix")
        if mustang_path.exists():
            recipe = self.parser.parse(mustang_path)
            self.assertEqual(recipe.packages[0].pname, "mustang")
            self.assertTrue(recipe.packages[0].update.enable)
            self.assertEqual(recipe.packages[0].update.post_script, "./update.sh")


if __name__ == "__main__":
    unittest.main()
