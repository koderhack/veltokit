import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import styles from './SkillDownloads.module.css';

const GITHUB_RAW_BASE =
  'https://raw.githubusercontent.com/koderhack/veltokit/main/website/static/skills';

type Props = {
  /** When false, parent page should provide its own heading (and anchor id). */
  showHeading?: boolean;
};

export default function SkillDownloads({showHeading = true}: Props): JSX.Element {
  const {siteConfig} = useDocusaurusContext();
  const siteSkillsBase = `${siteConfig.url}${siteConfig.baseUrl}skills/`;
  const cursorSkillRaw = `${GITHUB_RAW_BASE}/cursor-skill.md`;
  const claudeSkillRaw = `${GITHUB_RAW_BASE}/claude-skill.md`;
  const cursorSkillSite = `${siteSkillsBase}cursor-skill.md`;
  const claudeSkillSite = `${siteSkillsBase}claude-skill.md`;

  return (
    <div className={styles.wrap}>
      {showHeading ? (
        <h3 id="download-ai-skills">Download AI skills</h3>
      ) : null}
      <p className={styles.lead}>
        One-file prompts for Cursor or Claude. In a clone they are at{' '}
        <code>website/static/skills/</code>. Use the docs <strong>Search</strong> box in the
        navbar (<kbd>⌘K</kbd> / <kbd>Ctrl+K</kbd>) to find SDK topics quickly.
      </p>
      <p className={styles.leadPl}>
        <strong>PL:</strong> Wyszukiwarka — pole <strong>Search</strong> w prawym górnym rogu
        (`⌘K` / `Ctrl+K`). Pobranie skilli — przyciski poniżej lub menu <strong>AI Skills</strong>{' '}
        → <em>↓ Download Cursor (.md)</em> / <em>↓ Download Claude (.md)</em>.
      </p>
      <div className={styles.grid}>
        <a
          className={styles.card}
          href={cursorSkillRaw}
          download="cursor-skill.md"
          target="_blank"
          rel="noopener noreferrer">
          <span className={styles.label}>Cursor</span>
          <span className={styles.file}>cursor-skill.md</span>
          <span className={styles.action}>Download</span>
        </a>
        <a
          className={styles.card}
          href={claudeSkillRaw}
          download="claude-skill.md"
          target="_blank"
          rel="noopener noreferrer">
          <span className={styles.label}>Claude</span>
          <span className={styles.file}>claude-skill.md</span>
          <span className={styles.action}>Download</span>
        </a>
      </div>
      <details className={styles.details}>
        <summary>Direct links (copy)</summary>
        <ul>
          <li>
            <strong>On this site:</strong>{' '}
            <a href={cursorSkillSite} target="_blank" rel="noopener noreferrer">
              {cursorSkillSite}
            </a>
          </li>
          <li>
            <strong>On this site:</strong>{' '}
            <a href={claudeSkillSite} target="_blank" rel="noopener noreferrer">
              {claudeSkillSite}
            </a>
          </li>
          <li>
            <strong>GitHub raw:</strong>{' '}
            <a href={cursorSkillRaw} target="_blank" rel="noopener noreferrer">
              {cursorSkillRaw}
            </a>
          </li>
          <li>
            <strong>GitHub raw:</strong>{' '}
            <a href={claudeSkillRaw} target="_blank" rel="noopener noreferrer">
              {claudeSkillRaw}
            </a>
          </li>
        </ul>
      </details>
      <p className={styles.hint}>
        <strong>Cursor:</strong> save as <code>.cursor/skills/veltokit/SKILL.md</code> in this
        repo, or paste into chat / User Rules. <strong>Claude:</strong> add to Project
        instructions or paste at the start of a chat.
      </p>
    </div>
  );
}
