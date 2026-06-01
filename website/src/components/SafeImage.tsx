import clsx from 'clsx';
import {useAssetSrc} from '@site/src/utils/useAssetSrc';
import styles from './SafeImage.module.css';

/** Paths that need logo masking (hardware photos). */
const RISKY_PATH_RE = /\/(device\/cap|triki\/)/i;

export type SafeImageProps = {
  src: string;
  alt?: string;
  className?: string;
  imgClassName?: string;
  /** Force or skip brand masking. Default: auto-detect from src. */
  maskBrand?: boolean;
  /** Optional overlay label on masked area. Default: none (logo already softened in assets). */
  overlayText?: string;
  /** center = localized mask on logo area; none = no mask */
  blurMode?: 'center' | 'none';
  /** Show small corner badge instead of center overlay */
  badgePosition?: 'center' | 'corner';
  width?: number;
  height?: number;
  loading?: 'lazy' | 'eager';
  fetchPriority?: 'high' | 'low' | 'auto';
  /** Use gradient placeholder instead of src (e.g. too risky asset removed) */
  placeholder?: boolean;
  placeholderLabel?: string;
};

export function isRiskyImageSrc(src: string): boolean {
  return RISKY_PATH_RE.test(src);
}

export default function SafeImage({
  src,
  alt = '',
  className,
  imgClassName,
  maskBrand,
  overlayText = '',
  blurMode = 'center',
  badgePosition = 'center',
  width,
  height,
  loading = 'lazy',
  fetchPriority,
  placeholder = false,
  placeholderLabel = 'Generic BLE controller',
}: SafeImageProps): JSX.Element {
  const resolved = useAssetSrc(src);
  const shouldMask = maskBrand ?? isRiskyImageSrc(src);

  if (placeholder) {
    return (
      <div
        className={clsx(styles.wrap, styles.placeholder, className)}
        role="img"
        aria-label={alt || placeholderLabel}>
        {placeholderLabel}
      </div>
    );
  }

  const maskActive = shouldMask && blurMode === 'center';
  const showOverlay = shouldMask && overlayText && badgePosition === 'center';
  const showCorner = shouldMask && overlayText && badgePosition === 'corner';

  return (
    <span
      className={clsx(
        styles.wrap,
        'safe-image',
        maskActive && styles.centerMask,
        maskActive && blurMode === 'center' && styles.blurCenter,
        className,
      )}>
      <img
        src={resolved}
        alt={alt}
        className={clsx(styles.img, imgClassName)}
        width={width}
        height={height}
        loading={loading}
        {...(fetchPriority ? {fetchPriority} : {})}
        decoding="async"
      />
      {showOverlay ? (
        <span className={styles.badge} aria-hidden>
          {overlayText}
        </span>
      ) : null}
      {showCorner ? (
        <span className={clsx(styles.badge, styles.cornerBadge)} aria-hidden>
          {overlayText}
        </span>
      ) : null}
    </span>
  );
}
