import type {ReactNode} from 'react';
import {useAssetSrc} from '@site/src/utils/useAssetSrc';
import styles from './SafeVideo.module.css';

type Props = {
  src: string;
  title?: ReactNode;
  description?: ReactNode;
  className?: string;
};

/** Demo recordings may show real hardware — corner badge for legal clarity. */
export default function SafeVideo({src, title, description, className}: Props): JSX.Element {
  const resolved = useAssetSrc(src);

  return (
    <div className={`${styles.wrap} safe-video ${className ?? ''}`.trim()}>
      <video className={styles.video} controls playsInline preload="metadata">
        <source src={resolved} type="video/mp4" />
      </video>
      <span className={styles.badge} aria-hidden>
        DEMO
      </span>
      {title ? <h3 className={styles.title}>{title}</h3> : null}
      {description ? <p className={styles.desc}>{description}</p> : null}
    </div>
  );
}
