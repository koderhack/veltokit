import {type KeyboardEvent, useCallback, useEffect, useRef, useState} from 'react';
import SafeImage from '@site/src/components/SafeImage';
import styles from './DeviceCapVisual.module.css';

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
};

/** Pasek posX jak w aplikacji — środek + wypełnienie w lewo/prawo, klik / przeciąganie. */
function PosXBar({posX, onChange}: PosXBarProps): JSX.Element {
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
      dragging.current = false;
    };
    window.addEventListener('pointermove', onMove);
    window.addEventListener('pointerup', onUp);
    return () => {
      window.removeEventListener('pointermove', onMove);
      window.removeEventListener('pointerup', onUp);
    };
  }, [setFromClientX]);

  const onKeyDown = (e: KeyboardEvent<HTMLDivElement>) => {
    const step = e.shiftKey ? 0.1 : 0.04;
    if (e.key === 'ArrowLeft' || e.key === 'ArrowDown') {
      e.preventDefault();
      onChange(Math.max(0, posX - step));
    } else if (e.key === 'ArrowRight' || e.key === 'ArrowUp') {
      e.preventDefault();
      onChange(Math.min(1, posX + step));
    } else if (e.key === 'Home') {
      e.preventDefault();
      onChange(0);
    } else if (e.key === 'End') {
      e.preventDefault();
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
      onPointerDown={(e) => {
        dragging.current = true;
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

/** Generic BLE cap — obrót zgodny z paskiem posX */
export default function DeviceCapVisual(): JSX.Element {
  const [posX, setPosX] = useState(0.5);
  const reducedMotion = useReducedMotion();
  const deg = (posX - 0.5) * 72;

  const setPosXClamped = useCallback((x: number) => {
    setPosX(Math.min(1, Math.max(0, x)));
  }, []);

  return (
    <div className={styles.stage}>
      <div className={styles.controller} aria-hidden>
        <div className={styles.capSpin}>
          <div
            className={styles.capRotor}
            style={reducedMotion ? undefined : {transform: `rotate(${deg}deg)`}}>
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
        <PosXBar posX={posX} onChange={setPosXClamped} />
      </div>
    </div>
  );
}
