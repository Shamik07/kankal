# Web stack decisions

Checked against official guidance and current stable package releases on 26 September 2026.

- [Vite's guide](https://vite.dev/guide/) lists the `react-ts` template, `bun create vite`, and Node 20.19+ or 22.12+ compatibility. This starter uses Vite 8.3.1 and `@vitejs/plugin-react` 6.1.1 with Node 26 available locally.
- [Bun's Vite guide](https://bun.com/docs/guides/ecosystem/vite) supports installing and running Vite with Bun without a special adapter. Bun owns package installation and scripts; `bun.lock` pins the resolved tree.
- [shadcn/ui's Vite guide](https://ui.shadcn.com/docs/installation/vite) uses Tailwind CSS 4, `@tailwindcss/vite`, a TypeScript `@` alias, and the shadcn CLI. Components are copied into `src/components/ui/` so each copied product can adapt them. The CLI version is 4.21.0.
- [Vitest's guide](https://vitest.dev/guide/) recommends installing Vitest alongside Vite. Vitest 5.0.2 runs focused API and React behavior tests with Testing Library and jsdom.
- [Playwright's guide](https://playwright.dev/docs/intro) provides browser-level journey tests and trace reports. Playwright 1.63.0 runs the same demo journey in desktop Chrome, phone emulation, and a 320px viewport. CI installs the Chrome channel before the browser run.
- [Storybook's React/Vite guide](https://storybook.js.org/docs/get-started/frameworks/react-vite) provides an isolated component workbench. Storybook and `@storybook/react-vite` 10.6.0 build stories beside the shared components, using the app's Vite and Tailwind configuration.

React 19.3.0, TypeScript 7.0.2, Tailwind CSS 4.3.3, React Router 7.18.4, and the other direct dependencies were selected from the current stable npm registry releases. Versions in `package.json` and the frozen Bun lockfile are the source of truth. The stack stays small: no backend client, storage package, form framework, remote logger, or pagination library is needed for the in-memory demo.
