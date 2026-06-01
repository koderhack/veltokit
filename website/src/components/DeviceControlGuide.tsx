import {useEffect, useMemo, useState} from 'react';
import Link from '@docusaurus/Link';
import Translate, {translate} from '@docusaurus/Translate';
import SafeImage from '@site/src/components/SafeImage';
import {
  GamePreviewMini,
  type GamePreviewId,
} from '@site/src/components/GamePreview';
import styles from './DeviceControlGuide.module.css';

const capBle = '/img/device/cap-hero.png';

type StepId = 'connect' | 'pong' | 'dart' | 'bowling' | 'quiz';

type GuideStep = {
  id: StepId;
  title: string;
  tab: string;
  layer: string;
  game: string;
  mode: string;
  signal: string;
  pipeline: string;
  bullets: string[];
  docTo: string;
  docLabel: string;
};

function useSteps(): readonly GuideStep[] {
  return useMemo(
    () =>
      [
        {
          id: 'connect',
          title: translate({
            id: 'guide.connect.title',
            message: '1. Pair over BLE',
          }),
          tab: translate({id: 'guide.connect.tab', message: 'BLE connect'}),
          layer: translate({
            id: 'guide.connect.layer',
            message: 'Platform · TrikiInputAdapter',
          }),
          game: translate({id: 'guide.connect.game', message: 'gametriki app'}),
          mode: translate({id: 'guide.connect.mode', message: 'BLE scan & notify'}),
          signal: translate({
            id: 'guide.connect.signal',
            message: 'GATT notify → [UInt8]',
          }),
          pipeline: translate({
            id: 'guide.connect.pipeline',
            message:
              'Peripheral → BLEManager → MotionParser → MotionSDK.enqueueBLE',
          }),
          bullets: [
            translate({
              id: 'guide.connect.b1',
              message:
                'Main menu → **Connect** (or **POŁĄCZ BLE**) — CoreBluetooth scan starts.',
            }),
            translate({
              id: 'guide.connect.b2',
              message:
                'Tap your cap in the list; iOS opens a GATT link and subscribes to **notify** characteristics.',
            }),
            translate({
              id: 'guide.connect.b3',
              message:
                'Each notify payload is raw bytes (`0x22` gyro blocks, button on `bytes[1]`) — not `GameInput` yet.',
            }),
            translate({
              id: 'guide.connect.b4',
              message:
                '`TrikiInputAdapter` forwards packets to `MotionSDK`; when the stream is live you get a **calibration** prompt.',
            }),
            translate({
              id: 'guide.connect.b5',
              message:
                'Hold the cap level, centered — `performCalibration()` stores neutral pose. All sample games then use `pollInput()`.',
            }),
          ],
          docTo: '/docs/sdk/ble-integration',
          docLabel: translate({
            id: 'guide.connect.doc',
            message: 'BLE integration (packets & adapter)',
          }),
        },
        {
          id: 'pong',
          title: translate({
            id: 'guide.pong.title',
            message: '2. Paddle — tilt',
          }),
          tab: translate({id: 'guide.pong.tab', message: 'Paddle'}),
          layer: translate({id: 'guide.layer.veltokit', message: 'VeltoKit · MotionSDK'}),
          game: translate({id: 'guide.pong.game', message: 'Pong'}),
          mode: '.paddle',
          signal: 'posX · didShoot',
          pipeline: translate({
            id: 'guide.pong.pipeline',
            message: 'MotionSDK.updateFrame → GameInput → PongGame.update',
          }),
          bullets: [
            translate({
              id: 'guide.pong.b1',
              message:
                '`GameManager.applyMotionMode(.pong)` loads `MotionConfig.preset(for: .paddle)`.',
            }),
            translate({
              id: 'guide.pong.b2',
              message: 'Tilt left/right integrates into **posX** — paddle position on the court.',
            }),
            translate({
              id: 'guide.pong.b3',
              message:
                'Optional cap button → **didShoot** (serve / actions) via `primaryAction`.',
            }),
          ],
          docTo: '/docs/examples/pong',
          docLabel: translate({id: 'guide.pong.doc', message: 'Pong example'}),
        },
        {
          id: 'dart',
          title: translate({
            id: 'guide.dart.title',
            message: '3. Dart — aim + throw',
          }),
          tab: translate({id: 'guide.dart.tab', message: 'Dart'}),
          layer: translate({id: 'guide.layer.veltokit', message: 'VeltoKit · MotionSDK'}),
          game: translate({id: 'guide.dart.game', message: 'Dart'}),
          mode: '.pointer',
          signal: 'posX · posY · sensors',
          pipeline: translate({
            id: 'guide.dart.pipeline',
            message:
              'GameInput + DartThrowController → flight & score (phone or TV)',
          }),
          bullets: [
            translate({
              id: 'guide.dart.b1',
              message:
                'Sample uses **.pointer** for aim; `DartThrowController` reads **sensors** (tilt/gyro) for pull-back → throw.',
            }),
            translate({
              id: 'guide.dart.b2',
              message:
                'You can prototype with **.gesture** and `shotTriggered` + `throwPower` instead — see Bowling step.',
            }),
            translate({
              id: 'guide.dart.b3',
              message:
                'Board renders on the **phone** by default; enable TV in lobby when AirPlay is connected.',
            }),
          ],
          docTo: '/docs/examples/dart',
          docLabel: translate({id: 'guide.dart.doc', message: 'Dart example'}),
        },
        {
          id: 'bowling',
          title: translate({
            id: 'guide.bowling.title',
            message: '4. Bowling — gesture throw',
          }),
          tab: translate({id: 'guide.bowling.tab', message: 'Bowling'}),
          layer: translate({id: 'guide.layer.veltokit', message: 'VeltoKit · MotionSDK'}),
          game: translate({id: 'guide.bowling.game', message: 'Bowling 3D'}),
          mode: '.gesture',
          signal: 'shotTriggered · throwPower · posX',
          pipeline: translate({
            id: 'guide.bowling.pipeline',
            message: 'Gesture FSM → SceneKit impulse on lane',
          }),
          bullets: [
            translate({
              id: 'guide.bowling.b1',
              message:
                '`MotionMode.gesture` — pull-back sets **gesturePrimed**; forward edge → **shotTriggered** once per roll.',
            }),
            translate({
              id: 'guide.bowling.b2',
              message:
                '**throwPower** (0…1) scales physics impulse; **posX** aims across the lane.',
            }),
            translate({
              id: 'guide.bowling.b3',
              message:
                'Full **3D lane on iPhone**; optional mirror to TV with “lane on television” + AirPlay.',
            }),
          ],
          docTo: '/docs/examples/bowling',
          docLabel: translate({id: 'guide.bowling.doc', message: 'Bowling example'}),
        },
        {
          id: 'quiz',
          title: translate({
            id: 'guide.quiz.title',
            message: '5. Quiz — focus + confirm',
          }),
          tab: translate({id: 'guide.quiz.tab', message: 'Quiz'}),
          layer: translate({id: 'guide.layer.veltokit', message: 'VeltoKit · MotionSDK'}),
          game: translate({id: 'guide.quiz.game', message: 'Quiz'}),
          mode: '.paddle',
          signal: 'posX · primaryAction',
          pipeline: translate({
            id: 'guide.quiz.pipeline',
            message: 'posX → answer slot A–D · button edge → submit',
          }),
          bullets: [
            translate({
              id: 'guide.quiz.b1',
              message:
                'Sample maps **posX** to four answer slots (`TrikiUIMath.focusedSlot`) with a neutral center band.',
            }),
            translate({
              id: 'guide.quiz.b2',
              message:
                'Cap button rising edge → **primaryAction** (same path as `didShoot` convenience).',
            }),
            translate({
              id: 'guide.quiz.b3',
              message:
                'Questions on **external display** when AirPlay is on; phone stays the remote.',
            }),
          ],
          docTo: '/docs/examples/quiz',
          docLabel: translate({id: 'guide.quiz.doc', message: 'Quiz example'}),
        },
      ] as const,
    [],
  );
}

const previewByStep: Record<StepId, GamePreviewId | null> = {
  connect: null,
  pong: 'pong',
  dart: 'dart',
  bowling: 'bowling',
  quiz: 'quiz',
};

export default function DeviceControlGuide(): JSX.Element {
  const steps = useSteps();
  const [active, setActive] = useState(0);

  useEffect(() => {
    const id = window.setInterval(() => {
      setActive((i) => (i + 1) % steps.length);
    }, 5500);
    return () => window.clearInterval(id);
  }, [steps.length]);

  const step = steps[active];
  const previewId = previewByStep[step.id];

  return (
    <div className={styles.root}>
      <p className={styles.lead}>
        <Translate id="guide.lead">
          Five layers from pairing to play — same GameInput contract in every sample
          game. Tap a step or wait for auto-advance.
        </Translate>
      </p>

      <div className={styles.tabs} role="tablist" aria-label="Input mapping steps">
        {steps.map((s, i) => (
          <button
            key={s.id}
            type="button"
            role="tab"
            aria-selected={i === active}
            className={`${styles.tab} ${i === active ? styles.tabActive : ''}`}
            onClick={() => setActive(i)}>
            {s.tab}
          </button>
        ))}
      </div>

      <div className={styles.stage}>
        <div className={`${styles.photoWrap} ${styles[`anim_${step.id}`]}`}>
          {previewId ? (
            <GamePreviewMini id={previewId} className={styles.gamePreview} />
          ) : (
            <SafeImage
              src={capBle}
              alt=""
              className={styles.photoSafe}
              imgClassName={styles.photo}
              blurMode="none"
              maskBrand={false}
            />
          )}
          <div className={styles.overlay} aria-hidden>
            {step.id === 'pong' && (
              <>
                <span className={styles.arrowLeft}>← posX</span>
                <span className={styles.arrowRight}>posX →</span>
              </>
            )}
            {step.id === 'dart' && (
              <>
                <span className={styles.phaseBack}>AIM</span>
                <span className={styles.phaseThrow}>THROW</span>
              </>
            )}
            {step.id === 'bowling' && (
              <>
                <span className={styles.phaseBack}>BACK</span>
                <span className={styles.phaseThrow}>THROW</span>
                <svg className={styles.throwArc} viewBox="0 0 120 80">
                  <path
                    d="M10 70 Q60 10 110 50"
                    fill="none"
                    stroke="rgba(236,72,153,0.8)"
                    strokeWidth="3"
                  />
                </svg>
              </>
            )}
            {step.id === 'quiz' && <span className={styles.aimBar} />}
            {step.id === 'connect' && <span className={styles.blePulse} />}
          </div>
        </div>

        <div className={styles.copy}>
          <p className={styles.layerLabel}>{step.layer}</p>
          <p className={styles.gameLabel}>
            {step.game} · <code>{step.mode}</code>
          </p>
          <h3 className={styles.stepTitle}>{step.title}</h3>
          <p className={styles.pipeline}>{step.pipeline}</p>
          <p className={styles.signal}>
            <Translate id="guide.output">VeltoKit output:</Translate>{' '}
            <code>{step.signal}</code>
          </p>
          <ul className={styles.bullets}>
            {step.bullets.map((line, i) => (
              <li key={i} dangerouslySetInnerHTML={{__html: formatBold(line)}} />
            ))}
          </ul>
          <Link to={step.docTo} className={styles.docLink}>
            {step.docLabel} →
          </Link>
        </div>
      </div>
    </div>
  );
}

/** `**bold**` in translated strings → <strong> */
function formatBold(text: string): string {
  return text.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
}
