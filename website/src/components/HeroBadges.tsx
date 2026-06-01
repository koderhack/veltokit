import Translate from '@docusaurus/Translate';
import styles from './HeroBadges.module.css';

export default function HeroBadges(): JSX.Element {
  return (
    <div className={styles.row}>
      <span className={styles.badge}>
        <Translate id="hero.badge.experimental">Experimental</Translate>
      </span>
      <span className={styles.badgeAccent}>
        <Translate id="hero.badge.ble">BLE SDK</Translate>
      </span>
    </div>
  );
}
