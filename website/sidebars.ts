import type {SidebarsConfig} from '@docusaurus/plugin-content-docs';

const sidebars: SidebarsConfig = {
  docs: [
    {
      type: 'category',
      label: 'Start here',
      collapsed: false,
      items: [
        'intro',
        'quick-start',
        'getting-started',
        'installation',
        'demo',
      ],
    },
    {
      type: 'category',
      label: 'VeltoKit SDK',
      link: {type: 'doc', id: 'sdk/overview'},
      collapsed: false,
      items: [
        'sdk/overview',
        'sdk/architecture',
        'sdk/modules',
        'sdk/motion-sdk',
        'sdk/game-input',
        'sdk/triki-ui',
        'sdk/configuration',
        'sdk/gestures',
        'sdk/ble-integration',
      ],
    },
    {
      type: 'category',
      label: 'Game examples',
      link: {
        type: 'generated-index',
        slug: '/category/examples',
        title: 'Game examples',
        description:
          'How each sample game maps cap motion to GameInput — Pong, Dart, Bowling, Quiz.',
      },
      items: [
        'examples/pong',
        'examples/dart',
        'examples/bowling',
        'examples/quiz',
      ],
    },
    {
      type: 'category',
      label: 'Developer workflow',
      collapsed: false,
      items: [
        'ai-context',
        'for-cursor-claude',
        'for-cursor',
        'for-claude',
        {
          type: 'link',
          label: '↓ Download skills',
          href: '/docs/for-cursor-claude#download-ai-skills',
        },
      ],
    },
    {
      type: 'category',
      label: 'Support',
      collapsed: false,
      items: ['faq'],
    },
  ],
};

export default sidebars;
