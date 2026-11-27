// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

// https://astro.build/config
export default defineConfig({
	// Hosted on GitHub Pages as a project site: derlioapp.github.io/raku_router/.
	// `base` must match the repo name; if you move to a root custom domain,
	// drop `base` (and point `site` at that domain).
	site: 'https://derlioapp.github.io',
	base: '/raku_router',
	integrations: [
		starlight({
			title: 'raku_router',
			customCss: ['./src/styles/custom.css'],
			description:
				'A tiny, code-generation-free, UI-agnostic router for Flutter: ' +
				'type-safe sealed routes, declarative deep linking, and built-in ' +
				'nested tabs with per-branch back stacks.',
			tagline: 'A tiny, code-generation-free router for Flutter.',
			social: [
				{
					icon: 'github',
					label: 'GitHub',
					href: 'https://github.com/derlioapp/raku_router',
				},
				{
					icon: 'seti:dart',
					label: 'pub.dev',
					href: 'https://pub.dev/packages/raku_router',
				},
			],
			editLink: {
				baseUrl: 'https://github.com/derlioapp/raku_router/edit/main/website/',
			},
			sidebar: [
				{
					label: 'Start here',
					items: [
						{ label: 'Getting started', slug: 'getting-started' },
						{ label: 'Why raku_router', slug: 'why' },
						{ label: 'Live demo', slug: 'live-demo' },
					],
				},
				{
					label: 'Tutorial',
					items: [
						{ label: 'Build a notes app', slug: 'tutorial' },
					],
				},
				{
					label: 'Concepts',
					items: [
						{ label: 'The mental model', slug: 'concepts/mental-model' },
						{ label: 'URL ⇄ stack', slug: 'concepts/url-and-stack' },
						{ label: 'Tabs & preserved state', slug: 'concepts/tabs-state' },
					],
				},
				{
					label: 'Guides',
					items: [
						{ label: 'Route tree & deep linking', slug: 'guides/route-tree' },
						{ label: 'Tabs & nested navigation', slug: 'guides/tabs' },
						{ label: 'Guards & redirects', slug: 'guides/guards-redirects' },
						{ label: 'Transitions', slug: 'guides/transitions' },
						{ label: 'Web', slug: 'guides/web' },
						{ label: 'State restoration', slug: 'guides/state-restoration' },
						{ label: 'Observability', slug: 'guides/observability' },
					],
				},
				{
					label: 'Recipes',
					items: [
						{ label: 'Bottom-nav app', slug: 'recipes/bottom-nav' },
						{ label: 'Auth / redirect gate', slug: 'recipes/auth-gate' },
						{ label: 'Deep link to a detail screen', slug: 'recipes/deep-link-detail' },
						{ label: 'Not-found (404) pages', slug: 'recipes/not-found' },
						{ label: 'Unsaved-changes guard', slug: 'recipes/unsaved-changes' },
						{ label: 'Screen-view analytics', slug: 'recipes/analytics' },
						{ label: 'Clean web URLs', slug: 'recipes/web-urls' },
					],
				},
				{
					label: 'Reference',
					items: [
						{
							label: 'API reference (pub.dev)',
							link: 'https://pub.dev/documentation/raku_router/latest/',
							attrs: { target: '_blank', rel: 'noopener' },
							badge: { text: 'dartdoc', variant: 'note' },
						},
						{ label: 'Changelog', slug: 'changelog' },
					],
				},
			],
		}),
	],
});
