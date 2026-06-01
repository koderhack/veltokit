import {translate} from '@docusaurus/Translate';
import SafeVideo from '@site/src/components/SafeVideo';
import styles from './DemoVideos.module.css';

export default function DemoVideos(): JSX.Element {
  return (
    <div className={styles.wrap}>
      <article className={styles.videoCard}>
        <SafeVideo
          src="/videos/triki-connect.mp4"
          title={translate({
            id: 'demo.video.connect.title',
            message: 'BLE pairing (sample app)',
          })}
          description={translate({
            id: 'demo.video.connect.body',
            message:
              'Scan, connect, calibration flow in the lab build. Recordings may show generic hardware; no brand affiliation.',
          })}
        />
      </article>
      <article className={styles.videoCard}>
        <SafeVideo
          src="/videos/triki-games.mp4"
          title={translate({
            id: 'demo.video.games.title',
            message: 'Game smoke tests',
          })}
          description={translate({
            id: 'demo.video.games.body',
            message:
              'Pong, Dart, Bowling, Quiz — same GameInput contract. Unofficial demo footage.',
          })}
        />
      </article>
    </div>
  );
}
