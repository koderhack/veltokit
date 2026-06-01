import Link from '@docusaurus/Link';
import BrowserOnly from '@docusaurus/BrowserOnly';
import Translate, {translate} from '@docusaurus/Translate';
import GameIcon from '@site/src/components/GameIcon';
import {GamePreviewCanvas, type GamePreviewId} from '@site/src/components/GamePreview';
import {GAME_DOC_PATHS} from '@site/src/games/gameDocPaths';
import styles from './GameExamplesSection.module.css';

function useGames() {
  const games: {
    id: GamePreviewId;
    title: string;
    movement: string;
    inGame: string;
    mode: string;
  }[] = [
    {
      id: 'pong',
      title: 'Pong',
      movement: translate({
        id: 'games.pong.movement',
        message: 'Tilt left / right',
      }),
      inGame: translate({
        id: 'games.pong.inGame',
        message: 'Moves the paddle along the bottom edge',
      }),
      mode: '.paddle',
    },
    {
      id: 'dart',
      title: 'Dart',
      movement: translate({
        id: 'games.dart.movement',
        message: 'Pull back, then flick forward',
      }),
      inGame: translate({
        id: 'games.dart.inGame',
        message: 'Aims with tilt; throw power sets dart velocity',
      }),
      mode: '.pointer',
    },
    {
      id: 'bowling',
      title: 'Bowling',
      movement: translate({
        id: 'games.bowling.movement',
        message: 'Swing motion + aim tilt',
      }),
      inGame: translate({
        id: 'games.bowling.inGame',
        message:
          'Lane offset from tilt; swing maps to ball power (3D SceneKit demo)',
      }),
      mode: '.gesture',
    },
    {
      id: 'quiz',
      title: 'Quiz',
      movement: translate({
        id: 'games.quiz.movement',
        message: 'Tilt to highlight · press to confirm',
      }),
      inGame: translate({
        id: 'games.quiz.inGame',
        message: 'Selects answer A–D; button edge submits',
      }),
      mode: '.paddle',
    },
  ];
  return games;
}

export default function GameExamplesSection(): JSX.Element {
  const games = useGames();

  return (
    <div className={styles.grid}>
      {games.map((g) => (
        <Link
          key={g.id}
          to={GAME_DOC_PATHS[g.id]}
          className={styles.cardLink}
          aria-label={translate({
            id: 'games.openDocs',
            message: 'Open {game} documentation',
            values: {game: g.title},
          })}>
          <article className={styles.card}>
            <div className={styles.preview}>
              <BrowserOnly fallback={<div className={styles.fallback}>…</div>}>
                {() => <GamePreviewCanvas id={g.id} />}
              </BrowserOnly>
            </div>
            <div className={styles.body}>
              <div className={styles.titleRow}>
                <GameIcon id={g.id} size={36} />
                <h3 className={styles.title}>{g.title}</h3>
              </div>
              <p className={styles.movement}>
                <strong>
                  <Translate id="games.you">You:</Translate>
                </strong>{' '}
                {g.movement}
              </p>
              <p className={styles.inGame}>
                <strong>
                  <Translate id="games.inGame">In game:</Translate>
                </strong>{' '}
                {g.inGame}
              </p>
              <p className={styles.mode}>
                <code>setMode({g.mode})</code>
              </p>
              <span className={styles.cta}>
                <Translate id="games.openDocsCta">Open game docs →</Translate>
              </span>
            </div>
          </article>
        </Link>
      ))}
    </div>
  );
}
