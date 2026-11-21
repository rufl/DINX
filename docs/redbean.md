# Redbean shell

Redbean is the experimental DINX shell for the `SHELL` branch. It targets
NEXT first; MAIN remains on Morghulis until the shell passes the session,
accessibility, theme, and hardware qualification gates.

## Product contract

- One start surface exposes search, categories, pinned DINX apps, and session
  actions without nested menus.
- Windows mode is the default for people coming from Windows 7: categories stay
  visible beside results.
- Flow mode is keyboard-first: search owns the top of the surface and results
  fill one direct launch list.
- Application discovery and fuzzy matching come from Astal Apps. Launches use
  desktop-entry APIs, never shell interpolation.
- Theme colors come from GTK semantic roles. Redbean does not override the
  selected DINX theme, dark/light variant, font, or corner policy.
- The package is not in `profile.yaml` and the current supervisor does not
  start it. That is deliberate until NEXT qualification is complete.
## Integrated shell surface

The qualified prototype closes the shell gaps without adding a resident
daemon:

- KWM's stock `Mod4-p` launcher is migrated to Redbean on NEXT when the
  package is installed; custom KWM bindings are preserved.
- Astal Apps provides fuzzy application search. `settings:` searches the
  curated settings catalog, and `file:` searches the user's home directory
  with bounded recursion.
- Windows mode exposes editable pins. Redbean persists desktop ids and sends
  `SIGHUP` to `dinx-dock`, which reloads the same list.
- Focus previous/next and workspace previous/next issue River commands through
  Astal River. Volume and mute use Astal WirePlumber.
- Network, Bluetooth, audio, package, and DINX control-center actions launch
  fixed desktop/system entries. Application **Manage** resolves desktop-entry
  ownership with pacman and asks for polkit authentication before removal.
- Astal Notifd notifications are listed, counted, and dismissible; the tray
  count and control-center action keep status affordances reachable.

All external launches use fixed argv or GIO desktop/URI APIs. Optional
applications can be absent without enabling arbitrary shell execution.
## Visual quality bar

Redbean's minimum visual and interaction quality is the level represented by
the [Astal showcases](https://www.astal.dev/showcases/), with DINX-specific
improvements where the shell can be clearer, faster, or more cohesive. Astal
is an inspiration and quality reference, not a runtime dependency or a request
to copy another shell's identity.

Before Redbean can replace or join the MAIN shell, both modes must have:

- a deliberate visual system for hierarchy, spacing, typography, iconography,
  surfaces, focus states, and motion; no placeholder-looking GTK composition;
- equal-quality pointer and keyboard workflows, visible focus, Escape dismissal,
  predictable Enter activation, and accessible labels;
- polished light and dark presentations across all four DINX theme families,
  with semantic colors and verified contrast rather than theme-specific hacks;
- responsive behavior at supported display sizes and scales, including safe
  coexistence with every supported `dinx-dock` placement;
- restrained, purposeful transitions that preserve responsiveness and respect
  reduced-motion preferences;
- startup and interaction performance consistent with a lightweight shell:
  no extra daemon, no shell command interpolation, and no visible search or
  launch jank.

The visual qualification gate is two modes across four theme families and both
light/dark variants, with the dock set to `left`, `right`, `bottom`, and
`none`. Screenshots alone are insufficient: keyboard, pointer, focus,
launching, lock, logout, and dock-layout behavior must be exercised in the
running NEXT session. The current prototype is a functional baseline, not the
final visual quality bar.

## Qualification before MAIN


1. Run the package in the River/KWM NEXT session on each supported renderer.
2. Verify keyboard navigation, Escape dismissal, focus visibility, and screen
   reader labels.
3. Verify all four DINX theme families in light and dark variants.
4. Verify app discovery, missing desktop entries, launch failures, lock, and
   logout behavior.
5. Add it to the session supervisor only after the existing Morghulis/dock
   path has an explicit migration decision and a matching static contract.
