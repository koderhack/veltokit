import Translate, {translate} from '@docusaurus/Translate';
import Link from '@docusaurus/Link';
import CodeBlock from '@theme/CodeBlock';
import styles from './TryItFiveMinutes.module.css';

const SWIFT_SAMPLE = `import VeltoKit

let motion = MotionSDK()
motion.setMode(.paddle)
motion.connect()

// Game loop (~60 Hz):
let input = motion.pollInput(deltaTime: dt)
// input.posX, input.primaryAction, …`;

function IconPackage(): JSX.Element {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden>
      <path d="M12 2 2 7l10 5 10-5-10-5Z" />
      <path d="m2 17 10 5 10-5M2 12l10 5 10-5" />
    </svg>
  );
}

function IconBluetooth(): JSX.Element {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden>
      <path d="m7 7 10 10-5 5V2l5 5-5 5" />
    </svg>
  );
}

function IconMotion(): JSX.Element {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden>
      <circle cx="12" cy="12" r="3" />
      <path d="M12 2v4M12 18v4M4.93 4.93l2.83 2.83M16.24 16.24l2.83 2.83M2 12h4M18 12h4M4.93 19.07l2.83-2.83M16.24 7.76l2.83-2.83" />
    </svg>
  );
}

function IconMap(): JSX.Element {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden>
      <path d="M14.5 5.5 18 4l4 2v12l-4-2-3.5 1.5L9 19l-4-2V5l4 2 3.5-1.5Z" />
      <path d="m9 5 6 3M9 19l6-3M15 8l-6 3" />
    </svg>
  );
}

type StepProps = {
  icon: () => JSX.Element;
  label: string;
  title: string;
  desc: string;
};

function StepRow({icon: Icon, label, title, desc}: StepProps): JSX.Element {
  return (
    <li className={styles.step}>
      <div className={styles.stepIcon}>
        <Icon />
      </div>
      <div>
        <span className={styles.stepNum}>{label}</span>
        <h3 className={styles.stepTitle}>{title}</h3>
        <p className={styles.stepDesc}>{desc}</p>
      </div>
    </li>
  );
}

export default function TryItFiveMinutes(): JSX.Element {
  return (
    <section className={styles.section} aria-labelledby="try-it-5-heading">
      <header className={styles.header}>
        <p className={styles.eyebrow}>
          <Translate id="tryIt5.eyebrow">Swift · BLE · Motion</Translate>
        </p>
        <h2 id="try-it-5-heading" className={styles.title}>
          <Translate id="tryIt5.title">Try it in 5 minutes</Translate>
        </h2>
        <p className={styles.subtitle}>
          <Translate id="tryIt5.subtitle">
            Build your first motion-controlled app using Swift and Triki.
          </Translate>
        </p>
      </header>

      <div className={styles.grid}>
        <ol className={styles.steps}>
          <StepRow
            icon={IconPackage}
            label={translate({id: 'tryIt5.step1.label', message: 'Step 1'})}
            title={translate({id: 'tryIt5.step1.title', message: 'Install SDK'})}
            desc={translate({
              id: 'tryIt5.step1.desc',
              message: 'Add Triki SDK to your project',
            })}
          />
          <StepRow
            icon={IconBluetooth}
            label={translate({id: 'tryIt5.step2.label', message: 'Step 2'})}
            title={translate({id: 'tryIt5.step2.title', message: 'Connect device'})}
            desc={translate({
              id: 'tryIt5.step2.desc',
              message: 'Scan and connect via BLE',
            })}
          />
          <StepRow
            icon={IconMotion}
            label={translate({id: 'tryIt5.step3.label', message: 'Step 3'})}
            title={translate({id: 'tryIt5.step3.title', message: 'Read motion'})}
            desc={translate({
              id: 'tryIt5.step3.desc',
              message: 'Receive tilt, shake, and press input',
            })}
          />
          <StepRow
            icon={IconMap}
            label={translate({id: 'tryIt5.step4.label', message: 'Step 4'})}
            title={translate({id: 'tryIt5.step4.title', message: 'Map to action'})}
            desc={translate({
              id: 'tryIt5.step4.desc',
              message: 'Use motion to control your app',
            })}
          />
        </ol>

        <div className={styles.codePanel}>
          <div className={styles.codeHeader}>
            <div className={styles.codeDots} aria-hidden>
              <span />
              <span />
              <span />
            </div>
            <span className={styles.codeLang}>Swift</span>
          </div>
          <CodeBlock language="swift" showLineNumbers>
            {SWIFT_SAMPLE}
          </CodeBlock>
          <p className={styles.codeCaption}>
            <Translate id="tryIt5.codeCaption">
              MotionSDK.connect() scans and links; pollInput() returns GameInput each
              frame. Your own BLE? Use enqueueBLE instead — see the quick start.
            </Translate>{' '}
            <Link to="/docs/quick-start">
              <Translate id="tryIt5.cta">Open Swift quick start</Translate>
            </Link>
          </p>
        </div>
      </div>
    </section>
  );
}
