import {themes as prismThemes} from 'prism-react-renderer';
import type {Config} from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';
import {footerLinks, navbarItems, plLegacyRedirects} from './siteRoutes';

const config: Config = {
  title: 'VeltoKit',
  tagline: 'Swift BLE motion SDK for iOS — GameInput every frame',
  favicon: 'img/favicon.svg',

  url: 'https://koderhack.github.io',
  baseUrl: '/veltokit/',
  organizationName: 'koderhack',
  projectName: 'veltokit',
  trailingSlash: false,

  onBrokenLinks: 'throw',
  onDuplicateRoutes: 'warn',

  themes: [
    [
      require.resolve('@easyops-cn/docusaurus-search-local'),
      {
        hashed: true,
        language: ['en'],
        docsRouteBasePath: 'docs',
        indexBlog: false,
        indexPages: true,
        highlightSearchTermsOnTargetPage: true,
        searchResultLimits: 12,
        searchBarShortcut: true,
        explicitSearchResultPath: true,
      },
    ],
  ],

  plugins: [
    [
      '@docusaurus/plugin-client-redirects',
      {
        redirects: [
          {from: '/docs', to: '/docs/intro'},
          {from: '/docs/motion-sdk', to: '/docs/sdk/motion-sdk'},
          {from: '/docs/input-system', to: '/docs/sdk/game-input'},
          {from: '/docs/gestures', to: '/docs/sdk/gestures'},
          {from: '/docs/configuration', to: '/docs/sdk/configuration'},
          ...plLegacyRedirects,
        ],
      },
    ],
  ],

  presets: [
    [
      'classic',
      {
        docs: {
          sidebarPath: './sidebars.ts',
          routeBasePath: 'docs',
          editUrl: 'https://github.com/koderhack/veltokit/tree/main/website/',
        },
        sitemap: {
          lastmod: 'date',
          changefreq: 'weekly',
          priority: 0.5,
          filename: 'sitemap.xml',
        },
        blog: false,
        theme: {
          customCss: './src/css/custom.css',
        },
      } satisfies Preset.Options,
    ],
  ],

  themeConfig: {
    image: 'img/veltokit-social-card.svg',
    metadata: [
      {name: 'theme-color', content: '#09090b'},
      {
        name: 'description',
        content:
          'VeltoKit maps BLE cap IMU + button data to GameInput for iOS games. Swift MotionSDK, sample app (Pong, Dart, Bowling, Quiz), and docs.',
      },
      {
        name: 'keywords',
        content:
          'VeltoKit, Swift, iOS, BLE, motion SDK, GameInput, MotionSDK, game controller, gyroscope, gametriki',
      },
      {property: 'og:type', content: 'website'},
      {name: 'twitter:card', content: 'summary_large_image'},
    ],
    colorMode: {
      defaultMode: 'dark',
      respectPrefersColorScheme: true,
    },
    navbar: {
      title: 'VeltoKit',
      logo: {alt: 'VeltoKit', src: 'img/logo.svg'},
      items: navbarItems,
    },
    footer: {
      style: 'dark',
      links: footerLinks,
      copyright: `© ${new Date().getFullYear()} VeltoKit — unofficial experiment. Not affiliated with any hardware brand.`,
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.vsDark,
      additionalLanguages: ['swift'],
    },
  } satisfies Preset.ThemeConfig,
};

export default config;
