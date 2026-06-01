import type {SidebarsConfig} from '@docusaurus/plugin-content-docs';

const sidebars: SidebarsConfig = {
  docs: [
    'intro',
    'demo',
    'quick-start',
    'getting-started',
    'installation',
    'faq',
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
  ],
};

export default sidebars;
