import Translate from '@docusaurus/Translate';
import styles from './ProjectDisclaimer.module.css';

type Props = {
  compact?: boolean;
  prominent?: boolean;
};

export default function ProjectDisclaimer({compact, prominent}: Props): JSX.Element {
  const className = prominent
    ? styles.prominent
    : compact
      ? styles.compact
      : styles.box;

  return (
    <aside className={className} role="note">
      <p>
        <strong>
          <Translate id="disclaimer.title">Independent experiment.</Translate>
        </strong>{' '}
        <Translate id="disclaimer.body">
          This repository is an unofficial, reverse-engineered BLE input stack for
          education and development. It is not affiliated with, endorsed by, or connected
          to any hardware manufacturer or brand. Trademarks and devices belong to their
          respective owners.
        </Translate>
      </p>
    </aside>
  );
}
