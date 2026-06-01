import {useEffect, useState} from 'react';
import Link from '@docusaurus/Link';
import BrowserOnly from '@docusaurus/BrowserOnly';
import PixelCanvas from '@site/src/components/PixelCanvas';
import QuizPreview from '@site/src/components/QuizPreview';
import {PixelContext} from '@site/src/games/pixelContext';
import {renderPongFrame} from '@site/src/games/pongPreview';
import {renderDartFrame} from '@site/src/games/dartPreview';
import {renderBowlingFrame} from '@site/src/games/bowlingPreview';
import type {DrawCommand} from '@site/src/games/pixelTypes';
import {GAME_DOC_PATHS} from '@site/src/games/gameDocPaths';
import styles from './GameShowcase.module.css';

export type GamePreviewId = 'pong' | 'dart' | 'bowling' | 'quiz';

const meta: Record<
  GamePreviewId,
  {title: string; mode: string; input: string; doc: string}
> = {
  pong: {
    title: 'Pong',
    mode: '.paddle',
    input: 'posX',
    doc: GAME_DOC_PATHS.pong,
  },
  dart: {
    title: 'Dart',
    mode: '.gesture',
    input: 'throwPower',
    doc: GAME_DOC_PATHS.dart,
  },
  bowling: {
    title: 'Bowling',
    mode: '.gesture',
    input: 'posX + power',
    doc: GAME_DOC_PATHS.bowling,
  },
  quiz: {
    title: 'Quiz',
    mode: '.pointer',
    input: 'posX + click',
    doc: GAME_DOC_PATHS.quiz,
  },
};

function renderPixelFrame(
  id: 'pong' | 'dart' | 'bowling',
  t: number,
): DrawCommand[] {
  const ctx = new PixelContext();
  if (id === 'pong') renderPongFrame(ctx, t);
  else if (id === 'dart') renderDartFrame(ctx, t);
  else renderBowlingFrame(ctx, t);
  return ctx.commands;
}

function PixelGamePreview({id}: {id: 'pong' | 'dart' | 'bowling'}): JSX.Element {
  const [commands, setCommands] = useState<DrawCommand[]>(() =>
    renderPixelFrame(id, 0),
  );

  useEffect(() => {
    let raf = 0;
    const tick = (now: number) => {
      const t = now / 1000;
      setCommands(renderPixelFrame(id, t));
      raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [id]);

  return (
    <div className={styles.pixelStage}>
      <PixelCanvas commands={commands} />
    </div>
  );
}

export function GamePreviewCanvas({id}: {id: GamePreviewId}): JSX.Element {
  return (
    <div className={styles.previewWrap}>
      {id === 'quiz' ? (
        <QuizPreview />
      ) : (
        <PixelGamePreview id={id} />
      )}
    </div>
  );
}

export default function GamePreview({id}: {id: GamePreviewId}): JSX.Element {
  const m = meta[id];
  return (
    <Link to={m.doc} className={styles.card}>
      <GamePreviewCanvas id={id} />
      <div className={styles.meta}>
        <h3>{m.title}</h3>
        <p>
          <code>{m.mode}</code> → <code>{m.input}</code>
        </p>
      </div>
    </Link>
  );
}

export function GamePreviewGrid(): JSX.Element {
  const ids: GamePreviewId[] = ['pong', 'dart', 'bowling', 'quiz'];
  return (
    <div className={styles.grid}>
      {ids.map((id) => (
        <GamePreview key={id} id={id} />
      ))}
    </div>
  );
}

/** Mini podgląd w przewodniku (bez linku). */
export function GamePreviewMini({
  id,
  className,
}: {
  id: GamePreviewId;
  className?: string;
}): JSX.Element {
  return (
    <BrowserOnly fallback={<div className={styles.fallback3d}>…</div>}>
      {() => (
        <div className={className ?? styles.previewWrap}>
          <GamePreviewCanvas id={id} />
        </div>
      )}
    </BrowserOnly>
  );
}
