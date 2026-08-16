/*
 * Rationale for this icon fallback listener
 *
 * - It is useful to never show broken icons to the user for the Applicaitons.
 * - Historically, we had urls of the form `/forge/apps/collabora-desktop-app` with the `-app` suffix
 *   For these urls we have a redirect but the application icon will be missing when visited via the old URL.
 *   See https://github.com/ngi-nix/forge/issues/545
 *
 * Inital attempt was a simple fix `attribute "onerror" ("this.onerror = null; this.src = '" ++ defaultAppIconPath ++ "'")`
 * Which is not allowed by elm as it is converting `onerror` attribute to `data-onerror`
 * Thus a dedicated file which adds these listeners. Even though dom lifecycle is manage by Elm, this still works.
 */
const AVATAR_COLORS = [
  // NixOS Dark Blue
  { light: "var(--nixos-dark-blue-l55)", dark: "var(--nixos-dark-blue-l45)" },
  // NixOS Light Blue
  { light: "var(--nixos-light-blue-l75)", dark: "var(--nixos-light-blue-l85)" },
  // Favicon Teal
  { light: "var(--favicon-teal-light)", dark: "var(--favicon-teal-dark)" },
  // Favicon Sky to Navy
  { light: "var(--favicon-sky-light)", dark: "var(--favicon-navy-dark)" },
  // Favicon Green
  { light: "var(--favicon-green-light)", dark: "var(--favicon-green-dark)" },
];
const wordSplitRegex = /\s+|\.+|_+|;+|-+|,+|\|+|\/+|\\+|"+|'+|\(+|\)+|#+|&+/;

function stripBracketedAnnotations(name) {
  const bracketRegex = /\s*[([{][^)\]}]*[)\]}]$/;
  let cleaned = name;
  while (bracketRegex.test(cleaned)) {
    cleaned = cleaned.replace(bracketRegex, "");
  }
  return cleaned.trim();
}

function getFirstGraphemeUpper(word) {
  if (!word || !word.length) return "";
  return Array.from(word)[0].toUpperCase();
}

function getInitials(s) {
  if (!s) return "";
  const initialsBasis = s.split("@")[0];
  const cleanedName = stripBracketedAnnotations(initialsBasis);
  const nameForInitials = cleanedName || initialsBasis;
  const words = nameForInitials.split(wordSplitRegex).filter(Boolean);
  if (words.length === 0) return "";
  const firstWord = words[0];
  const lastWord = words.length > 1 ? words[words.length - 1] : "";
  return getFirstGraphemeUpper(firstWord) + (lastWord ? getFirstGraphemeUpper(lastWord) : "");
}

function getAvatarSvg(displayName, pname) {
  const initials = getInitials(displayName) || getInitials(pname) || "?";

  let nameHash = 0;
  const hashBase = pname || displayName || "";
  for (const s of hashBase) {
    nameHash += Number(s.codePointAt(0));
  }
  const colorDef = AVATAR_COLORS[nameHash % AVATAR_COLORS.length];

  // Hexagon points (flat topped)
  const pts = "50,0 93.3,25 93.3,75 50,100 6.7,75 6.7,25";
  const uid = "av" + nameHash + Math.floor(Math.random() * 100000);

  const svg = `
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <style>
      .bg-${uid} { fill: ${colorDef.light}; }
      .fg-${uid} { fill: #000000; }
      @media (prefers-color-scheme: dark) {
        .bg-${uid} { fill: ${colorDef.dark}; }
        .fg-${uid} { fill: #FFFFFF; }
      }
    </style>
    <polygon class="bg-${uid}" points="${pts}" />
    <polygon points="50,0 93.3,25 93.3,75 50,100" fill="#ffffff" opacity="0.15" />
    <polygon points="50,4 89.8,27 89.8,73 50,96 10.2,73 10.2,27" fill="none" stroke="#ffffff" stroke-width="2" opacity="0.6" />
    <text class="fg-${uid}" x="50%" y="54%" dominant-baseline="middle" text-anchor="middle" font-family="system-ui, -apple-system, sans-serif" font-size="36" font-weight="600" letter-spacing="1">${initials}</text>
</svg>`.trim();
  return "data:image/svg+xml," + encodeURIComponent(svg);
}

class AvatarIcon extends HTMLElement {
  static get observedAttributes() {
    return ["data-app-name", "data-display-name", "class", "alt", "style"];
  }

  connectedCallback() {
    if (!this.style.display) {
      this.style.display = "inline-block";
    }
    this.render();
  }

  attributeChangedCallback(name, oldValue, newValue) {
    if (oldValue !== newValue) {
      this.render();
    }
  }

  render() {
    const appName = this.getAttribute("data-app-name") || "";
    const displayName = this.getAttribute("data-display-name") || appName;
    const svgUri = getAvatarSvg(displayName, appName);

    const svgCode = decodeURIComponent(svgUri.split(",")[1]);
    this.innerHTML = svgCode;
    const svg = this.querySelector("svg");
    if (svg) {
      svg.style.width = "100%";
      svg.style.height = "100%";
      svg.style.objectFit = "contain";
      if (this.hasAttribute("alt")) {
        svg.setAttribute("aria-label", this.getAttribute("alt"));
        svg.setAttribute("role", "img");
      }
    }
  }
}

export const registerIconFallbackonError = () => {
  if (!customElements.get("avatar-icon")) {
    customElements.define("avatar-icon", AvatarIcon);
  }
};
