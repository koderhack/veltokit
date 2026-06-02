import {type KeyboardEvent, useCallback, useEffect, useRef, useState} from 'react';
import SafeImage from '@site/src/components/SafeImage';
import styles from './DeviceCapVisual.module.css';

const SPIN_MS = 12_000;

function useReducedMotion(): boolean {
  const [reducedMotion, setReducedMotion] = useState(false);
  useEffect(() => {
    const mq = window.matchMedia('(prefers-reduced-motion: reduce)');
    const apply = () => setReducedMotion(mq.matches);
    apply();
    mq.addEventListener('change', apply);
    return () => mq.removeEventListener('change', apply);
  }, []);
  return reducedMotion;
}

type PosXBarProps = {
  posX: number;
  onChange: (x: number) => void;
  onScrubStart: () => void;
  onScrubEnd: () => void;
};

/** Pasek posX — środek + wypełnienie; klik / przeciąganie wstrzymuje auto-obrót. */
function PosXBar({posX, onChange, onScrubStart, onScrubEnd}: PosXBarProps): JSX.Element {
  const barRef = useRef<HTMLDivElement>(null);
  const dragging = useRef(false);
  const signed = posX * 2 - 1;
  const thumbPct = posX * 100;
  const fillWidthPct = Math.abs(signed) * 50;
  const fillLeftPct = signed < 0 ? 50 - fillWidthPct : 50;

  const setFromClientX = useCallback(
    (clientX: number) => {
      const el = barRef.current;
      if (!el) return;
      const {left, width} = el.getBoundingClientRect();
      if (width <= 0) return;
      onChange(Math.min(1, Math.max(0, (clientX - left) / width)));
    },
    [onChange],
  );

  useEffect(() => {
    const onMove = (e: PointerEvent) => {
      if (!dragging.current) return;
      setFromClientX(e.clientX);
    };
    const onUp = () => {
      if (dragging.current) {
        dragging.current = false;
        onScrubEnd();
      }
    };
    window.addEventListener('pointermove', onMove);
    window.addEventListener('pointerup', onUp);
    return () => {
      window.removeEventListener('pointermove', onMove);
      window.removeEventListener('pointerup', onUp);
    };
  }, [setFromClientX, onScrubEnd]);

  const onKeyDown = (e: KeyboardEvent<HTMLDivElement>) => {
    const step = e.shiftKey ? 0.1 : 0.04;
    if (e.key === 'ArrowLeft' || e.key === 'ArrowDown') {
      e.preventDefault();
      onScrubStart();
      onChange(Math.max(0, posX - step));
    } else if (e.key === 'ArrowRight' || e.key === 'ArrowUp') {
      e.preventDefault();
      onScrubStart();
      onChange(Math.min(1, posX + step));
    } else if (e.key === 'Home') {
      e.preventDefault();
      onScrubStart();
      onChange(0);
    } else if (e.key === 'End') {
      e.preventDefault();
      onScrubStart();
      onChange(1);
    }
  };

  return (
    <div
      ref={barRef}
      className={styles.bar}
      role="slider"
      tabIndex={0}
      aria-label="posX"
      aria-valuemin={-1}
      aria-valuemax={1}
      aria-valuenow={Number(signed.toFixed(2))}
      onKeyDown={onKeyDown}
      onBlur={onScrubEnd}
      onPointerDown={(e) => {
        dragging.current = true;
        onScrubStart();
        setFromClientX(e.clientX);
        e.currentTarget.setPointerCapture(e.pointerId);
      }}>
      <div className={styles.barTrack} />
      {fillWidthPct > 0.5 ? (
        <div
          className={styles.barFill}
          style={{left: `${fillLeftPct}%`, width: `${fillWidthPct}%`}}
        />
      ) : null}
      <div className={styles.barCenter} />
      <div className={styles.barThumb} style={{left: `${thumbPct}%`}} />
    </div>
  );
}

/** Kapsel — ciągły obrót + pasek posX zsynchronizowany (sin); pauza przy sterowaniu paskiem. */
export default function DeviceCapVisual(): JSX.Element {
  const [posX, setPosX] = useState(0.5);
  const [spinDeg, setSpinDeg] = useState(0);
  const reducedMotion = useReducedMotion();
  const autoPaused = useRef(false);
  const spinOrigin = useRef(performance.now());

  useEffect(() => {
    if (reducedMotion) return;

    let raf = 0;
    const tick = (now: number) => {
      if (!autoPaused.current) {
        const elapsed = (now - spinOrigin.current) % SPIN_MS;
        const angle = (elapsed / SPIN_MS) * 360;
        const rad = (angle * Math.PI) / 180;
        setSpinDeg(angle);
        setPosX((Math.sin(rad) + 1) / 2);
      }
      raf = requestAnimationFrame(tick);
    };

    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [reducedMotion]);

  const setPosXClamped = useCallback((x: number) => {
    const clamped = Math.min(1, Math.max(0, x));
    setPosX(clamped);
    const deg = clamped * 360;
    setSpinDeg(deg);
    spinOrigin.current = performance.now() - (deg / 360) * SPIN_MS;
  }, []);

  const onScrubStart = useCallback(() => {
    autoPaused.current = true;
  }, []);

  const onScrubEnd = useCallback(() => {
    autoPaused.current = false;
  }, []);

  return (
    <div className={styles.stage}>
      <div className={styles.controller} aria-hidden>
        <div className={styles.capSpin}>
          <div
            className={styles.capRotor}
            style={
              reducedMotion
                ? undefined
                : {transform: `rotate(${spinDeg}deg)`}
            }>
            <SafeImage
              src="/img/device/cap-hero.png"
              alt=""
              className={styles.capFrame}
              imgClassName={styles.capImg}
              blurMode="none"
              maskBrand={false}
              width={320}
              height={320}
              loading="eager"
              fetchPriority="high"
            />
          </div>
        </div>
      </div>
      <div className={styles.inputHud}>
        <span>posX</span>
        <PosXBar
          posX={posX}
          onChange={setPosXClamped}
          onScrubStart={onScrubStart}
          onScrubEnd={onScrubEnd}
        />
      </div>
    </div>
  );
}
