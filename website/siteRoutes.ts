/** Internal doc paths (English only). Use with Docusaurus `Link` / navbar `to`. */

export const DOC_PATHS = {
  intro: '/docs/intro',
  demo: '/docs/demo',
  quickStart: '/docs/quick-start',
  gettingStarted: '/docs/getting-started',
  installation: '/docs/installation',
  faq: '/docs/faq',
  canIUse: '/docs/can-i-use-this',
  sdkOverview: '/docs/sdk/overview',
  sdkArchitecture: '/docs/sdk/architecture',
  sdkModules: '/docs/sdk/modules',
  sdkMotionSdk: '/docs/sdk/motion-sdk',
  sdkGameInput: '/docs/sdk/game-input',
  sdkConfiguration: '/docs/sdk/configuration',
  sdkGestures: '/docs/sdk/gestures',
  sdkBle: '/docs/sdk/ble-integration',
  examplePong: '/docs/examples/pong',
  exampleDart: '/docs/examples/dart',
  exampleBowling: '/docs/examples/bowling',
  exampleQuiz: '/docs/examples/quiz',
} as const;

const d = DOC_PATHS;

/** Old /pl/ URLs → English docs (machine translation via Google in navbar). */
/** No `/pl/docs` alone — would clash with `/pl/docs/…` redirect files. */
export const plLegacyRedirects = [
  {from: '/pl', to: '/'},
  ...Object.values(DOC_PATHS).map((path) => ({
    from: `/pl${path}`,
    to: path,
  })),
];

export const navbarItems = [
  {
    to: '/',
    label: 'Home',
    position: 'left' as const,
    activeBaseRegex: '^/?$',
  },
  {
    to: d.intro,
    label: 'Docs',
    position: 'left' as const,
    activeBaseRegex: '/docs',
  },
  {
    to: d.demo,
    label: 'Demo',
    position: 'left' as const,
    activeBaseRegex: '/docs/demo',
  },
  {
    type: 'dropdown' as const,
    label: 'SDK',
    position: 'left' as const,
    items: [
      {to: d.sdkOverview, label: 'Overview'},
      {to: d.sdkMotionSdk, label: 'MotionSDK'},
      {to: d.sdkGameInput, label: 'GameInput'},
      {to: d.sdkBle, label: 'BLE'},
    ],
  },
  {
    type: 'dropdown' as const,
    label: 'Examples',
    position: 'left' as const,
    items: [
      {to: d.examplePong, label: 'Pong'},
      {to: d.exampleDart, label: 'Dart'},
      {to: d.exampleBowling, label: 'Bowling'},
      {to: d.exampleQuiz, label: 'Quiz'},
    ],
  },
  {
    href: 'https://github.com/koderhack/veltokit',
    label: 'GitHub',
    position: 'right' as const,
  },
];

export const footerLinks = [
  {
    title: 'Docs',
    items: [
      {label: 'Introduction', to: d.intro},
      {label: 'Quick Start', to: d.quickStart},
      {label: 'Getting Started', to: d.gettingStarted},
      {label: 'SDK Overview', to: d.sdkOverview},
      {label: 'Demo', to: d.demo},
      {label: 'Help', to: d.faq},
      {label: 'Can I use this?', to: d.canIUse},
    ],
  },
  {
    title: 'SDK',
    items: [
      {label: 'Architecture', to: d.sdkArchitecture},
      {label: 'MotionSDK API', to: d.sdkMotionSdk},
      {label: 'GameInput', to: d.sdkGameInput},
      {label: 'Configuration', to: d.sdkConfiguration},
      {label: 'BLE Integration', to: d.sdkBle},
    ],
  },
  {
    title: 'Examples',
    items: [
      {label: 'Pong', to: d.examplePong},
      {label: 'Dart', to: d.exampleDart},
      {label: 'Bowling', to: d.exampleBowling},
      {label: 'Quiz', to: d.exampleQuiz},
    ],
  },
  {
    title: 'More',
    items: [
      {
        label: 'GitHub',
        href: 'https://github.com/koderhack/veltokit',
      },
      {
        label: 'Sitemap',
        href: 'https://koderhack.github.io/veltokit/sitemap.xml',
      },
    ],
  },
];
