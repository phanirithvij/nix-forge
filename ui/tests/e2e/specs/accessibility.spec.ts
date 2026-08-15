import AxeBuilder from "@axe-core/playwright";
import { expect, test } from "@playwright/test";
import { BASE_URL } from "./constants";

const pagesToTest = ["/", "/apps", "/pkgs", "/recipe/options"];

test.describe("Color Contrast Accessibility", () => {
  for (const pagePath of pagesToTest) {
    for (const colorScheme of ["light", "dark"] as const) {
      test(`should have sufficient color contrast on ${pagePath} in ${colorScheme} mode`, async ({ page }) => {
        await page.emulateMedia({ colorScheme });
        await page.goto(`${BASE_URL}${pagePath}`);

        // Wait for the Elm app to mount
        await page.locator(".min-vh-100").waitFor();

        const accessibilityScanResults = await new AxeBuilder({ page })
          .withRules(["color-contrast"])
          .analyze();

        if (accessibilityScanResults.violations.length > 0) {
          console.error(`Violations on ${pagePath} in ${colorScheme} mode:`);
          for (const v of accessibilityScanResults.violations) {
            console.error(v.help);
            for (const node of v.nodes) {
              console.error(node.failureSummary);
              console.error(node.html);
            }
          }
        }

        expect(accessibilityScanResults.violations).toEqual([]);
      });
    }
  }
});

test.describe("Icon Modal Contrast", () => {
  for (const colorScheme of ["light", "dark"] as const) {
    test(`should have sufficient color contrast in ${colorScheme} mode`, async ({ page }) => {
      await page.emulateMedia({ colorScheme });
      await page.goto(`${BASE_URL}/apps`);
      await page.waitForSelector(".min-vh-100");

      // Click the first app to go to its page
      await page.click("[data-testid=\"app-result\"] >> nth=0");
      await page.waitForSelector(".item-header-icon");

      // Open the icon modal
      await page.click(".item-header-icon");
      await page.waitForSelector("[data-testid=\"icon-modal-container\"]");

      const accessibilityScanResults = await new AxeBuilder({ page })
        .withRules(["color-contrast"])
        .analyze();

      if (accessibilityScanResults.violations.length > 0) {
        console.error(`Violations in ${colorScheme} mode:`);
        for (const v of accessibilityScanResults.violations) {
          console.error(v.help);
          for (const node of v.nodes) {
            console.error(node.failureSummary);
            console.error(node.html);
          }
        }
      }

      expect(accessibilityScanResults.violations).toEqual([]);
    });
  }
});
