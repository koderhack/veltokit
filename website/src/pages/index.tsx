import Link from '@docusaurus/Link';
import Layout from '@theme/Layout';
import CodeBlock from '@theme/CodeBlock';
import Translate, {translate} from '@docusaurus/Translate';
import HeroBadges from '@site/src/components/HeroBadges';
import ProjectDisclaimer from '@site/src/components/ProjectDisclaimer';
import DeviceCapVisual from '@site/src/components/DeviceCapVisual';
import GameExamplesSection from '@site/src/components/GameExamplesSection';
import SkillDownloads from '@site/src/components/SkillDownloads';
import styles from './index.module.css';

const GITHUB = 'https://github.com/koderhack/veltokit';

const swiftIntegration = `import VeltoKit

let motion = MotionSDK()
motion.setMode(.paddle)

motion.connect()

func update(dt: TimeInterval) {
  let input = motion.pollInput(deltaTime: dt)
  paddle.x = CGFloat(input.posX) * viewWidth
  if input.didShoot { serveBall() }
}`;

const swiftMinimal = `import VeltoKit

let sdk = MotionSDK()
sdk.enqueueBLE(bleBytes)
sdk.updateFrame(deltaTime: dt)
let input = sdk.input  // posX, throwPower, didShoot, …`;

function useMotionInputs() {
  return [
    {
      name: translate({id: 'home.input.tilt.name', message: 'Tilt'}),
      field: 'posX, posY',
      map: translate({id: 'home.input.tilt.map', message: 'Aim, paddle, menu highlight'}),
    },
    {
      name: translate({id: 'home.input.rotation.name', message: 'Rotation'}),
      field: 'rotation, lateral',
      map: translate({
        id: 'home.input.rotation.map',
        message: 'Fine steering, alternate axis',
      }),
    },
    {
      name: translate({id: 'home.input.gesture.name', message: 'Gesture throw'}),
      field: 'shotTriggered, throwPower',
      map: translate({
        id: 'home.input.gesture.map',
        message: 'Dart, bowling, any powered action',
      }),
    },
    {
      name: translate({id: 'home.input.press.name', message: 'Press'}),
      field: 'didShoot, primaryAction',
      map: translate({id: 'home.input.press.map', message: 'Confirm, fire, menu OK'}),
    },
  ];
}

function useRoadmap() {
  return [
    {
      name: translate({id: 'home.roadmap.swift.name', message: 'Swift (iOS / macOS)'}),
      status: 'available' as const,
      note: translate({
        id: 'home.roadmap.swift.note',
        message: 'VeltoKit + sample Xcode project',
      }),
    },
    {
      name: translate({id: 'home.roadmap.godot.name', message: 'Godot plugin'}),
      status: 'soon' as const,
      note: translate({id: 'home.roadmap.godot.note', message: 'GDExtension bridge'}),
    },
    {
      name: translate({id: 'home.roadmap.unity.name', message: 'Unity SDK'}),
      status: 'soon' as const,
      note: translate({
        id: 'home.roadmap.unity.note',
        message: 'C# wrapper over BLE + input',
      }),
    },
  ];
}

export default function Home(): JSX.Element {
  const motionInputs = useMotionInputs();
  const roadmap = useRoadmap();

  return (
    <Layout
      title={translate({id: 'home.meta.title', message: 'Motion control for Swift'})}
      description={translate({
        id: 'home.meta.description',
        message:
          'Add BLE motion input to iOS games in minutes. VeltoKit + Triki experimental controller.',
      })}>
      <header className={styles.hero}>
        <div className={styles.heroGrid}>
          <div className={styles.heroCopy}>
            <HeroBadges />
            <h1 className={styles.heroTitle}>
              <Translate id="home.hero.title">
                Add motion control to your app in minutes
              </Translate>
            </h1>
            <p className={styles.heroSubtitle}>
              <Translate id="home.hero.subtitle">
                Use Triki with Swift to turn real-world movement into game input via BLE.
                One GameInput struct per frame — paddle, throw, or pointer.
              </Translate>
            </p>
            <div className={styles.heroCtas}>
              <Link className={styles.btnPrimary} to="/docs/quick-start">
                <Translate id="home.cta.docs">View Swift docs</Translate>
              </Link>
              <Link className={styles.btnGhost} to="/docs/getting-started">
                <Translate id="home.cta.demoApp">Build demo app</Translate>
              </Link>
            </div>
          </div>
          <div className={styles.heroVisual}>
            <DeviceCapVisual />
          </div>
        </div>
        <div className={styles.heroGlow} aria-hidden />
      </header>

      <main>
        <section className={styles.swiftSection} id="integrate">
          <div className={styles.sectionInner}>
            <div className={styles.split}>
              <div>
                <p className={styles.eyebrowLeft}>
                  <Translate id="home.swift.eyebrow">Swift</Translate>
                </p>
                <h2 className={styles.h2Left}>
                  <Translate id="home.swift.title">Integrate in minutes</Translate>
                </h2>
                <p className={styles.leadLeft}>
                  <Translate id="home.swift.lead">
                    Call connect(), then pollInput() each frame — MotionSDK handles BLE
                    scan and maps packets to GameInput. Or feed your own bytes with
                    enqueueBLE; TrikiInputAdapter in the sample app adds calibration UI.
                  </Translate>
                </p>
                <Link className={styles.linkBtn} to="/docs/quick-start">
                  <Translate id="home.swift.link">Open Swift quickstart →</Translate>
                </Link>
              </div>
              <div className={styles.codePanel}>
                <CodeBlock language="swift">{swiftIntegration}</CodeBlock>
              </div>
            </div>
          </div>
        </section>

        <section className={styles.howSection} id="how">
          <div className={styles.sectionInner}>
            <h2 className={styles.sectionTitle}>
              <Translate id="home.how.title">How it works</Translate>
            </h2>
            <div className={styles.steps}>
              <div className={styles.step}>
                <span className={styles.stepNum}>1</span>
                <h3>
                  <Translate id="home.how.step1.title">Connect via BLE</Translate>
                </h3>
                <p>
                  <Translate id="home.how.step1.body">
                    Scan for the Triki device, pair once, stream gyro + button bytes.
                  </Translate>
                </p>
              </div>
              <div className={styles.step}>
                <span className={styles.stepNum}>2</span>
                <h3>
                  <Translate id="home.how.step2.title">Read motion</Translate>
                </h3>
                <p>
                  <Translate id="home.how.step2.body">
                    Tilt, rotation, press — normalized and smoothed inside VeltoKit.
                  </Translate>
                </p>
              </div>
              <div className={styles.step}>
                <span className={styles.stepNum}>3</span>
                <h3>
                  <Translate id="home.how.step3.title">Map to game actions</Translate>
                </h3>
                <p>
                  <Translate id="home.how.step3.body">
                    Read GameInput each frame; drive sprites, UI, or physics.
                  </Translate>
                </p>
              </div>
            </div>
          </div>
        </section>

        <section className={styles.gamesSection} id="games">
          <div className={styles.sectionInner}>
            <h2 className={styles.sectionTitle}>
              <Translate id="home.games.title">Game examples</Translate>
            </h2>
            <p className={styles.sectionLead}>
              <Translate id="home.games.lead">
                Reference demos in this repo — copy the pattern, swap the art.
              </Translate>
            </p>
            <GameExamplesSection />
          </div>
        </section>

        <section className={styles.inputsSection} id="inputs">
          <div className={styles.sectionInner}>
            <h2 className={styles.sectionTitle}>
              <Translate id="home.inputs.title">Motion inputs</Translate>
            </h2>
            <p className={styles.sectionLead}>
              <Translate id="home.inputs.lead">
                Map hardware signals to gameplay with MotionSDK modes or direct fields on
                GameInput.
              </Translate>
            </p>
            <div className={styles.inputTable}>
              {motionInputs.map((row) => (
                <div key={row.name} className={styles.inputRow}>
                  <div className={styles.inputName}>{row.name}</div>
                  <div>
                    <code>{row.field}</code>
                  </div>
                  <div className={styles.inputMap}>{row.map}</div>
                </div>
              ))}
            </div>
            <div className={styles.codePanelNarrow}>
              <p className={styles.codeCaption}>
                <Translate id="home.inputs.sdkCaption">SDK-only path (no adapter):</Translate>
              </p>
              <CodeBlock language="swift">{swiftMinimal}</CodeBlock>
            </div>
          </div>
        </section>

        <section className={styles.roadmapSection} id="roadmap">
          <div className={styles.sectionInner}>
            <h2 className={styles.sectionTitle}>
              <Translate id="home.roadmap.title">SDK roadmap</Translate>
            </h2>
            <ul className={styles.roadmapList}>
              {roadmap.map((item) => (
                <li key={item.name} className={styles.roadmapItem}>
                  <div>
                    <strong>{item.name}</strong>
                    <span className={styles.roadmapNote}>{item.note}</span>
                  </div>
                  <span
                    className={
                      item.status === 'available' ? styles.badgeOk : styles.badgeSoon
                    }>
                    {item.status === 'available' ? (
                      <Translate id="home.roadmap.available">Available</Translate>
                    ) : (
                      <Translate id="home.roadmap.soon">Coming soon</Translate>
                    )}
                  </span>
                </li>
              ))}
            </ul>
          </div>
        </section>

        <section className={styles.demoSection} id="demo">
          <div className={styles.sectionInner}>
            <div className={styles.split}>
              <div>
                <h2 className={styles.h2Left}>
                  <Translate id="home.demo.title">Build a demo in Swift</Translate>
                </h2>
                <ol className={styles.demoSteps}>
                  <li>
                    <Translate id="home.demo.step1">
                      Clone the repo, cd app/, and open gametriki.xcodeproj in Xcode.
                    </Translate>
                  </li>
                  <li>
                    <Translate id="home.demo.step2">
                      Run on a physical iPhone — enable Bluetooth
                    </Translate>
                  </li>
                  <li>
                    <Translate id="home.demo.step3">
                      Connect your Triki device from the Connect screen
                    </Translate>
                  </li>
                  <li>
                    <Translate id="home.demo.step4">
                      Launch Pong, Dart, Bowling, or Quiz from the menu
                    </Translate>
                  </li>
                </ol>
                <div className={styles.demoCtas}>
                  <a className={styles.btnPrimary} href={GITHUB}>
                    <Translate id="home.demo.download">Download demo project</Translate>
                  </a>
                  <Link className={styles.btnGhost} to="/docs/demo">
                    <Translate id="home.demo.watch">Watch demos</Translate>
                  </Link>
                </div>
              </div>
              <div className={styles.demoAside}>
                <ProjectDisclaimer />
              </div>
            </div>
          </div>
        </section>

        <section className={styles.skillsSection} id="ai-skills">
          <div className={styles.sectionInner}>
            <h2 className={styles.sectionTitle}>
              <Translate id="home.skills.title">Docs search & AI skills</Translate>
            </h2>
            <p className={styles.skillsLead}>
              <Translate id="home.skills.lead">
                Search all documentation from the navbar (⌘K / Ctrl+K). Download
                ready-made Cursor or Claude prompt files below.
              </Translate>
            </p>
            <SkillDownloads />
            <Link className={styles.linkBtn} to="/docs/for-cursor-claude">
              <Translate id="home.skills.hub">Open full AI skills hub →</Translate>
            </Link>
          </div>
        </section>

        <section className={styles.finalCta}>
          <div className={styles.sectionInner}>
            <h2>
              <Translate id="home.final.title">Start building with motion</Translate>
            </h2>
            <p>
              <Translate id="home.final.lead">
                Swift-first SDK, open sample games, docs you can skim in five minutes.
              </Translate>
            </p>
            <div className={styles.heroCtas}>
              <Link className={styles.btnPrimary} to="/docs/intro">
                <Translate id="home.final.docs">Read docs</Translate>
              </Link>
              <Link className={styles.btnGhost} to="/docs/quick-start">
                <Translate id="home.final.starter">Get Swift starter</Translate>
              </Link>
            </div>
          </div>
        </section>
      </main>
    </Layout>
  );
}
