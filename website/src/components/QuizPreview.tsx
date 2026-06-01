import {useEffect, useRef, useState} from 'react';
import {focusedSlot} from '@site/src/games/trikiUIMath';
import styles from './QuizPreview.module.css';

/** Układ jak `QuizGameView` — wybór A–D z `posX` (obrót). */
export default function QuizPreview(): JSX.Element {
  const answers = ['Warszawa', 'Kraków', 'Gdańsk', 'Wrocław'];
  const [selected, setSelected] = useState(1);
  const focusRef = useRef(1);

  useEffect(() => {
    let raf = 0;
    const tick = (now: number) => {
      const t = now / 1000;
      const posX = Math.sin(t * 0.95) * 0.88;
      const next =
        focusedSlot(posX, 4, focusRef.current) ?? focusRef.current;
      focusRef.current = next;
      setSelected(next);
      raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, []);

  return (
    <div className={styles.screen}>
      <div className={styles.topBar}>
        <span className={styles.round}>Runda 1 · 120 pkt</span>
        <span className={styles.score}>3</span>
        <span className={styles.dot} />
      </div>

      <div className={styles.question}>
        <span className={styles.label}>PYTANIE · 0 pkt w rundzie</span>
        <p className={styles.text}>Stolicą Polski jest…</p>
      </div>

      <div className={styles.answers}>
        {answers.map((answer, i) => (
          <div
            key={answer}
            className={`${styles.row} ${i === selected ? styles.rowSelected : ''}`}>
            <span className={styles.letter}>{String.fromCharCode(65 + i)}</span>
            <span className={styles.answerText}>{answer}</span>
          </div>
        ))}
      </div>

      <p className={styles.hint}>Obrót = wybór A–D · hold = OK</p>
    </div>
  );
}
