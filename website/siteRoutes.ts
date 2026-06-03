/** Internal doc paths (English only). Use with Docusaurus `Link` / navbar `to`. */

export const DOC_PATHS = {
  intro: '/docs/intro',
  demo: '/docs/demo',
  quickStart: '/docs/quick-start',
  gettingStarted: '/docs/getting-started',
  installation: '/docs/installation',
  faq: '/docs/faq',
  aiContext: '/docs/ai-context',
  forCursorClaude: '/docs/for-cursor-claude',
  forCursor: '/docs/for-cursor',
  forClaude: '/docs/for-claude',
  sdkOverview: '/docs/sdk/overview',
  sdkArchitecture: '/docs/sdk/architecture',
  sdkModules: '/docs/sdk/modules',
  sdkMotionSdk: '/docs/sdk/motion-sdk',
  sdkGameInput: '/docs/sdk/game-input',
  sdkTrikiUi: '/docs/sdk/triki-ui',
  sdkConfiguration: '/docs/sdk/configuration',
  sdkGestures: '/docs/sdk/gestures',
  sdkBle: '/docs/sdk/ble-integration',
  examplePong: '/docs/examples/pong',
  exampleDart: '/docs/examples/dart',
  exampleBowling: '/docs/examples/bowling',
  exampleQuiz: '/docs/examples/quiz',
} as const;

/** Raw GitHub URLs — static /skills/*.md are not Docusaurus doc routes. */
export const SKILL_DOWNLOAD_URLS = {
  cursor:
    'https://raw.githubusercontent.com/koderhack/veltokit/main/website/static/skills/cursor-skill.md',
  claude:
    'https://raw.githubusercontent.com/koderhack/veltokit/main/website/static/skills/claude-skill.md',
} as const;

const d = DOC_PATHS;
const skills = SKILL_DOWNLOAD_URLS;

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
    to: d.forCursorClaude,
    label: 'For Cursor Claude',
    position: 'left' as const,
    activeBaseRegex: '/docs/for-cursor-claude',
  },
  {
    type: 'dropdown' as const,
    label: 'AI Skills',
    position: 'left' as const,
    items: [
      {to: d.aiContext, label: 'Context for AI'},
      {to: d.forCursorClaude, label: 'Hub + downloads'},
      {to: d.forCursor, label: 'Skill for Cursor'},
      {to: d.forClaude, label: 'Skill for Claude'},
      {href: skills.cursor, label: '↓ Download Cursor (.md)'},
      {href: skills.claude, label: '↓ Download Claude (.md)'},
    ],
  },
  {
    type: 'dropdown' as const,
    label: 'SDK',
    position: 'left' as const,
    items: [
      {to: d.sdkOverview, label: 'Overview'},
      {to: d.sdkMotionSdk, label: 'MotionSDK'},
      {to: d.sdkGameInput, label: 'GameInput'},
      {to: d.sdkTrikiUi, label: 'Triki UI'},
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
    type: 'search' as const,
    position: 'right' as const,
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
      {label: 'Context for AI', to: d.aiContext},
      {label: 'For Cursor Claude', to: d.forCursorClaude},
      {label: 'Skill for Cursor', to: d.forCursor},
      {label: 'Skill for Claude', to: d.forClaude},
      {label: 'Demo', to: d.demo},
      {label: 'Help', to: d.faq},
    ],
  },
  {
    title: 'SDK',
    items: [
      {label: 'Architecture', to: d.sdkArchitecture},
      {label: 'MotionSDK API', to: d.sdkMotionSdk},
      {label: 'GameInput', to: d.sdkGameInput},
      {label: 'Triki UI navigation', to: d.sdkTrikiUi},
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
    title: 'AI skills (download)',
    items: [
      {label: 'Cursor skill (.md)', href: skills.cursor},
      {label: 'Claude skill (.md)', href: skills.claude},
      {label: 'Skills hub (docs)', to: d.forCursorClaude},
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
