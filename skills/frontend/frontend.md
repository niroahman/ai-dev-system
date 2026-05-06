# Frontend stack

React + Next.js UI repos. Jest for unit/component tests. Playwright for e2e
when present.

## Defaults

- Prefer server components in Next.js unless interactivity requires client
- Co-locate component, styles, and test in the same directory
- Test behaviour, not implementation — avoid testing internal state or
  component structure directly
- When adding a component, add a Jest test unless it's a trivial wrapper
- Playwright tests: add only when the feature has a non-trivial user flow;
  don't add e2e for things already covered by Jest
- Use the project's existing import aliases — don't introduce new ones
- Don't mix client and server concerns in a single file

## Testing guidance

- Jest + React Testing Library: render, interact, assert on what the user sees
- Mock at the boundary (API calls, external modules), not inside the component
- Playwright: test from the user's perspective, not implementation details
- Check if `playwright.config.ts` exists before adding e2e tests — confirms
  Playwright is set up in this repo

## Patterns to follow

- Check existing components for naming and structure conventions before
  writing new ones
- If the repo uses a design system or component library, prefer its primitives
  over writing raw HTML elements
- Don't add client-side state management unless the component genuinely needs
  cross-subtree state — local useState is fine for local concerns
