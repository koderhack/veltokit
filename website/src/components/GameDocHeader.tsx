import type {GamePreviewId} from '@site/src/components/GamePreview';
import GameIcon from '@site/src/components/GameIcon';
import styles from './GameDocHeader.module.css';

type Props = {
  id: GamePreviewId;
  title: string;
  mode: string;
  fields?: string;
};

/** Icon + title row for game example docs */
export default function GameDocHeader({id, title, mode, fields}: Props): JSX.Element {
  return (
    <header className={styles.root}>
      <GameIcon id={id} size={52} />
      <div className={styles.copy}>
        <h1 className={styles.title}>{title}</h1>
        <p className={styles.meta}>
          <code>setMode({mode})</code>
          {fields ? (
            <>
              {' · '}
              <span className={styles.fields}>{fields}</span>
            </>
          ) : null}
        </p>
      </div>
    </header>
  );
}
