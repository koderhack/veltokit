import Link from '@docusaurus/Link';
import Translate, {translate} from '@docusaurus/Translate';
import styles from './SeoHomeSection.module.css';

type FaqItem = {q: string; a: string; href?: string; hrefLabel?: string};

function useFaqItems(): FaqItem[] {
  return [
    {
      q: translate({
        id: 'seo.faq.q1',
        message: 'What is VeltoKit?',
      }),
      a: translate({
        id: 'seo.faq.a1',
        message:
          'VeltoKit is a Swift framework that turns BLE cap IMU and button packets into a single GameInput struct each frame. It ships with a sample iOS app (gametriki) and full documentation.',
      }),
      href: '/docs/sdk/overview',
      hrefLabel: translate({id: 'seo.faq.link.sdk', message: 'SDK overview'}),
    },
    {
      q: translate({
        id: 'seo.faq.q2',
        message: 'Do I need the sample app?',
      }),
      a: translate({
        id: 'seo.faq.a2',
        message:
          'No. Link VeltoKit, call motion.connect() and pollInput() each frame, or feed your own BLE bytes with enqueueBLE. TrikiInputAdapter in the sample app is optional UI glue.',
      }),
      href: '/docs/installation',
      hrefLabel: translate({id: 'seo.faq.link.install', message: 'Installation'}),
    },
    {
      q: translate({
        id: 'seo.faq.q3',
        message: 'Which games are included?',
      }),
      a: translate({
        id: 'seo.faq.a3',
        message:
          'Pong (.paddle), Dart (.pointer + throw FSM), Bowling (.gesture), and Quiz (.paddle + button). Each example documents MotionMode and GameInput fields.',
      }),
      href: '/docs/examples/pong',
      hrefLabel: translate({id: 'seo.faq.link.examples', message: 'Game examples'}),
    },
    {
      q: translate({
        id: 'seo.faq.q4',
        message: 'Is this an official Triki SDK?',
      }),
      a: translate({
        id: 'seo.faq.a4',
        message:
          'No. Independent reverse-engineering for education. Packet layout may differ on your hardware — see BLE integration and DEV logs.',
      }),
      href: '/docs/faq',
      hrefLabel: translate({id: 'seo.faq.link.faq', message: 'FAQ'}),
    },
  ];
}

function usePillars() {
  return [
    {
      title: translate({id: 'seo.pillar.ble.title', message: 'BLE → bytes'}),
      body: translate({
        id: 'seo.pillar.ble.body',
        message: 'Documented gyro blocks (0x22) and button edges. Platform adapter or your own central manager.',
      }),
      to: '/docs/sdk/ble-integration',
    },
    {
      title: translate({id: 'seo.pillar.motion.title', message: 'MotionSDK'}),
      body: translate({
        id: 'seo.pillar.motion.body',
        message: 'Modes: paddle, pointer, gesture. Presets per game type. Calibrate once, poll every frame.',
      }),
      to: '/docs/sdk/motion-sdk',
    },
    {
      title: translate({id: 'seo.pillar.game.title', message: 'GameInput'}),
      body: translate({
        id: 'seo.pillar.game.body',
        message: 'posX, throwPower, shotTriggered, primaryAction — one struct for Pong, Dart, Bowling, Quiz.',
      }),
      to: '/docs/sdk/game-input',
    },
    {
      title: translate({id: 'seo.pillar.demo.title', message: 'Sample app'}),
      body: translate({
        id: 'seo.pillar.demo.body',
        message: 'Open-source VeltoKit on GitHub. Connect screen, calibration, four arcade demos.',
      }),
      to: '/docs/getting-started',
    },
  ];
}

export function faqPageJsonLd(items: FaqItem[]) {
  return {
    '@context': 'https://schema.org',
    '@type': 'FAQPage',
    mainEntity: items.map((item) => ({
      '@type': 'Question',
      name: item.q,
      acceptedAnswer: {
        '@type': 'Answer',
        text: item.a,
      },
    })),
  };
}

export default function SeoHomeSection(): JSX.Element {
  const faq = useFaqItems();
  const pillars = usePillars();

  return (
    <section className={styles.root} aria-labelledby="seo-overview-heading">
      <div className={styles.inner}>
        <div className={styles.about}>
          <p className={styles.eyebrow}>
            <Translate id="seo.eyebrow">Swift · iOS · BLE motion SDK</Translate>
          </p>
          <h2 id="seo-overview-heading" className={styles.title}>
            <Translate id="seo.title">
              VeltoKit — motion input SDK for iOS game developers
            </Translate>
          </h2>
          <p className={styles.lead}>
            <Translate id="seo.lead">
              Map a BLE cap controller to gameplay without writing parsers in every game.
              VeltoKit normalizes tilt, gestures, and button presses into GameInput;
              MotionSDK runs the per-frame pipeline with presets for paddle, pointer, and
              throw modes.
            </Translate>
          </p>
          <ul className={styles.keywordList} aria-label="Topics">
            {[
              'Swift',
              'iOS 16+',
              'CoreBluetooth',
              'GameInput',
              'MotionSDK',
              'BLE IMU',
              'Gesture throw',
              'Open source',
            ].map((tag) => (
              <li key={tag} className={styles.keyword}>
                {tag}
              </li>
            ))}
          </ul>
        </div>

        <div className={styles.pillars} role="list">
          {pillars.map((p) => (
            <Link key={p.to} className={styles.pillarCard} to={p.to} role="listitem">
              <h3 className={styles.pillarTitle}>{p.title}</h3>
              <p className={styles.pillarBody}>{p.body}</p>
              <span className={styles.pillarLink}>
                <Translate id="seo.pillar.read">Read docs →</Translate>
              </span>
            </Link>
          ))}
        </div>

        <div className={styles.faqBlock}>
          <h2 className={styles.faqHeading}>
            <Translate id="seo.faq.heading">Frequently asked questions</Translate>
          </h2>
          <div className={styles.faqList}>
            {faq.map((item) => (
              <details key={item.q} className={styles.faqItem}>
                <summary className={styles.faqQuestion}>{item.q}</summary>
                <div className={styles.faqAnswer}>
                  <p>{item.a}</p>
                  {item.href ? (
                    <Link to={item.href} className={styles.faqLink}>
                      {item.hrefLabel}
                    </Link>
                  ) : null}
                </div>
              </details>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}
