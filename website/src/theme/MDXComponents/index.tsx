import type {ComponentProps} from 'react';
import MDXComponents from '@theme-original/MDXComponents';
import SafeImage, {isRiskyImageSrc} from '@site/src/components/SafeImage';
import SafeVideo from '@site/src/components/SafeVideo';
import GameDocHeader from '@site/src/components/GameDocHeader';
import GameIcon from '@site/src/components/GameIcon';
import {useAssetSrc} from '@site/src/utils/useAssetSrc';

function MdxImage(props: ComponentProps<'img'>): JSX.Element {
  const src = typeof props.src === 'string' ? props.src : '';
  if (!src) return <img {...props} />;

  if (isRiskyImageSrc(src)) {
    return (
      <SafeImage
        src={src}
        alt={props.alt ?? ''}
        className="doc-safe-cap"
        width={320}
        height={320}
      />
    );
  }

  const resolved = useAssetSrc(src);
  return <img {...props} src={resolved} />;
}

export default {
  ...MDXComponents,
  img: MdxImage,
  SafeImage,
  SafeVideo,
  GameDocHeader,
  GameIcon,
};
