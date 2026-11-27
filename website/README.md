# raku_router docs site

The documentation site for [`raku_router`](..), built with
[Astro Starlight](https://starlight.astro.build). Brand: **derlio.app**.

## Develop

```bash
pnpm install
pnpm dev          # http://localhost:4321
```

Content lives in `src/content/docs/` (`.md` / `.mdx`); the sidebar and site
config are in `astro.config.mjs`.

## The live demo

The "Live demo" page embeds the package's `example/` app, built for web and
served from `/raku_router/demo/` (the GitHub Pages base). It is **generated**
(~40 MB) and git-ignored — build it before `pnpm build` / deploy:

```bash
# from the repo root
cd example
flutter create . --platforms web        # one-time, if web/ is missing
flutter build web --base-href /raku_router/demo/ --no-tree-shake-icons
rm -rf ../website/public/demo && mkdir -p ../website/public/demo
cp -R build/web/* ../website/public/demo/
```

## Build & deploy

```bash
pnpm build        # → ./dist (static)
pnpm preview      # check ./dist locally
```

Deploy `./dist` to any static host. The repo ships a GitHub Actions workflow
(`.github/workflows/docs.yaml`) that builds the Flutter demo + the site and
deploys to **GitHub Pages**. Enable it once under **Settings → Pages → Build and
deployment → Source: GitHub Actions**; every push to `main` that touches
`website/` or `example/` then publishes to `https://derlioapp.github.io/raku_router/`.

> URL strategy: served as a GitHub Pages **project site** under the `/raku_router`
> base path (set via `base: '/raku_router'` in `astro.config.mjs`, with the demo
> built `--base-href /raku_router/demo/`). To move to a root custom domain instead,
> drop `base`, rebuild the demo with `--base-href /demo/`, and add a `CNAME`.
