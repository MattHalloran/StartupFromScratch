# Testing

## Overview

We use **Mocha**, **Chai (v5+)**, and **Sinon** for unit tests. Tests are written in TypeScript and co‑located with code:

```
packages/ui/src/components/CustomButton.tsx
packages/ui/src/components/CustomButton.test.ts
packages/ui/src/components/CustomButton.stories.tsx
```

## Test Environment

- `.env-test` at project root sets test‑DB URLs and other variables (ignored via `.gitignore`).  
- Use `dotenv-cli` to load `.env-test` before test runs.

## Build‑Tests & Run

Each package `package.json` includes scripts:

```json
"pretest":   "rimraf dist && pnpm --filter @vrooli/shared run build",
"build-tests": "NODE_ENV=test swc src -d dist --config-file ../../.swcrc",
"test":      "pnpm run build-tests && dotenv -e ../../.env-test -- mocha --file dist/__test/setup.js \"dist/**/*.test.js\"",
"test-watch":   "pnpm run build-tests && dotenv -e ../../.env-test -- mocha --watch --file dist/__test/setup.js \"dist/**/*.test.js\""
```

- **`build-tests`** uses SWC to compile `src/**/*.ts?(x)` → `dist/` (with source maps).  
- **`dist/__test/setup.js`** contains global setup: 
  - Registers Chai's `expect` and Sinon on `globalThis`.

### Running All Tests

From the root, run:
```bash
pnpm test
```
This invokes `pnpm -r run test` to execute each package's `test` script.

## Storybook & Stories

We co‑locate Storybook stories next to components (`*.stories.tsx`). You can run Storybook separately:
```bash
# Inside ui package
pnpm --filter @vrooli/ui run dev   # if using Vite-based Storybook
```

--- 