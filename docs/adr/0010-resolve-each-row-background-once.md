# Trust theme colors and resolve each background once

Grove reads only the documented colors from native Helix Styles and trusts every
color that Helix or the user supplies. It does not repair equal colors or
calculate substitutes. Source modifiers and underline are ignored because Steel
does not expose them for safe inspection and composition.

Grove resolves each content background once, then draws only foreground changes
and ignored-status dimming over it. The Rail owns its separate cell background.
This prevents a foreground change from replacing or reversing a row background.

Revisit this decision when Steel exposes safe native Style patching and modifier
inspection, or when Helix changes foreground-only Style application.
