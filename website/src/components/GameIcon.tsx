import type {GamePreviewId} from '@site/src/components/GamePreview';
import styles from './GameIcon.module.css';

const ACCENT: Record<GamePreviewId, string> = {
  pong: '#22d3ee',
  dart: '#4ade80',
  bowling: '#fb923c',
  quiz: '#e879f9',
};

type Props = {
  id: GamePreviewId;
  size?: number;
  className?: string;
};

export default function GameIcon({id, size = 40, className}: Props): JSX.Element {
  const accent = ACCENT[id];
  return (
    <span
      className={[styles.wrap, className].filter(Boolean).join(' ')}
      style={{width: size, height: size, color: accent}}
      aria-hidden>
      {id === 'pong' && <PongIcon />}
      {id === 'dart' && <DartIcon />}
      {id === 'bowling' && <BowlingIcon />}
      {id === 'quiz' && <QuizIcon />}
    </span>
  );
}

function PongIcon() {
  return (
    <svg viewBox="0 0 32 32" fill="none" className={styles.svg}>
      <rect x="4" y="4" width="24" height="24" rx="4" stroke="currentColor" strokeWidth="1.5" opacity="0.5" />
      <line x1="6" y1="10" x2="26" y2="10" stroke="currentColor" strokeWidth="1" opacity="0.35" />
      <rect x="11" y="24" width="10" height="2" rx="1" fill="currentColor" />
      <circle cx="16" cy="14" r="2.5" fill="currentColor" />
    </svg>
  );
}

function DartIcon() {
  return (
    <svg viewBox="0 0 32 32" fill="none" className={styles.svg}>
      <circle cx="16" cy="16" r="11" stroke="currentColor" strokeWidth="1.5" />
      <circle cx="16" cy="16" r="6" stroke="currentColor" strokeWidth="1.25" opacity="0.7" />
      <circle cx="16" cy="16" r="2" fill="currentColor" />
      <path d="M16 5v3M16 24v3M5 16h3M24 16h3" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
    </svg>
  );
}

function BowlingIcon() {
  return (
    <svg viewBox="0 0 32 32" fill="none" className={styles.svg}>
      <path d="M8 26h16" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" opacity="0.5" />
      <circle cx="16" cy="12" r="5" stroke="currentColor" strokeWidth="1.5" />
      <circle cx="12" cy="18" r="3" fill="currentColor" opacity="0.85" />
      <circle cx="16" cy="19" r="3" fill="currentColor" opacity="0.85" />
      <circle cx="20" cy="18" r="3" fill="currentColor" opacity="0.85" />
    </svg>
  );
}

function QuizIcon() {
  return (
    <svg viewBox="0 0 32 32" fill="none" className={styles.svg}>
      <rect x="5" y="5" width="22" height="22" rx="5" stroke="currentColor" strokeWidth="1.5" />
      <path
        d="M13 12a3 3 0 1 1 4.2 2.8c-.9.5-1.2 1.1-1.2 2.2"
        stroke="currentColor"
        strokeWidth="1.75"
        strokeLinecap="round"
      />
      <circle cx="15.5" cy="22" r="1.25" fill="currentColor" />
    </svg>
  );
}
