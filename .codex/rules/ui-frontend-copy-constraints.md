# UI Frontend Copy Constraints

When designing or implementing UI/frontend experiences, obey these constraints globally.

## Mandatory Per-Operation Enforcement

- This rule applies to every UI/frontend operation, including new screens, redesigns, small component edits, copy tweaks, styling passes, prototypes, landing pages, dashboards, forms, modals, games, and interactive tools.
- Treat these constraints as hard requirements, not taste preferences.
- Before editing UI code, plan the visible text so it contains only functional or domain-needed copy.
- After editing UI code, audit all visible text and remove anything that violates this document before reporting completion.
- If a user request appears to require forbidden helper, explanatory, or implementation text, ask for explicit confirmation before adding it.

## Hard Rules

- Do not add instructional helper text, usage tips, onboarding copy, feature explanations, or "how to use this" text inside the UI unless the user explicitly asks for it.
- Do not add explanatory filler text that describes what the interface does, what a section is for, or why a design choice exists.
- Do not add technology-stack or implementation explanations in the UI, including text such as "built with React", "powered by", "uses local storage", "API-driven", or similar engineering/process copy.
- Do not add visible text that explains keyboard shortcuts, layout behavior, styling choices, animations, architecture, data flow, model behavior, or component implementation.
- Do not insert placeholder marketing copy just to fill space.
- Do not compensate for empty layouts by adding prose. Prefer real controls, data, assets, spacing, icons, states, and interaction affordances.

## Allowed UI Text

- Real product or domain content requested by the user.
- Navigation labels, page titles, section names, field labels, table headers, button text, menu items, filters, tabs, chips, and status labels.
- User-facing validation errors, destructive-action confirmations, loading states, empty states, permissions prompts, and accessibility labels when they are necessary for the workflow.
- Legal, billing, safety, privacy, or compliance text when the product context genuinely requires it.
- Copy that exists in a source design, screenshot, product spec, or user-provided content.

## Code Comments

- Implementation explanations may appear only as code comments when they help future maintainers.
- Keep code comments concise and technical. Do not mirror these comments as visible UI copy.

## Self-Check Before Finishing

Before delivering a UI/frontend change, scan the visible interface text and remove any line that reads like:

- a tutorial
- a design explanation
- an implementation note
- a technology-stack mention
- filler prose
- a feature pitch that the user did not ask for
