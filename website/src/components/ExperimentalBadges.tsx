import styles from './ExperimentalBadges.module.css';

export default function ExperimentalBadges(): JSX.Element {
  return (
    <div className={styles.row} aria-label="Project status">
      <span className={styles.badge}>Experimental</span>
      <span className={styles.badge}>Unofficial</span>
      <span className={styles.badge}>Dev tool</span>
    </div>
  );
}
