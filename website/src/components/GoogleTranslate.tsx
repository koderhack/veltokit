import {useEffect, useRef} from 'react';
import BrowserOnly from '@docusaurus/BrowserOnly';
import styles from './GoogleTranslate.module.css';

declare global {
  interface Window {
    googleTranslateElementInit?: () => void;
    google?: {
      translate: {
        TranslateElement: new (
          options: {
            pageLanguage?: string;
            includedLanguages?: string;
            layout?: number;
            autoDisplay?: boolean;
          },
          elementId: string,
        ) => void;
        TranslateElement: {
          InlineLayout: {SIMPLE: number};
        };
      };
    };
  }
}

const SCRIPT_ID = 'google-translate-script';
const ELEMENT_ID = 'google_translate_element';

function GoogleTranslateInner(): JSX.Element {
  const hostRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!hostRef.current || document.getElementById(SCRIPT_ID)) {
      return;
    }

    window.googleTranslateElementInit = () => {
      const el = document.getElementById(ELEMENT_ID);
      if (!el || !window.google?.translate) return;
      el.innerHTML = '';
      new window.google.translate.TranslateElement(
        {
          pageLanguage: 'en',
          includedLanguages:
            'pl,de,es,fr,it,pt,nl,uk,ja,ko,zh-CN,zh-TW,ar,hi,sv,da,fi,no,cs,sk,hu,ro',
          layout: window.google.translate.TranslateElement.InlineLayout.SIMPLE,
          autoDisplay: false,
        },
        ELEMENT_ID,
      );
    };

    const script = document.createElement('script');
    script.id = SCRIPT_ID;
    script.src =
      'https://translate.google.com/translate_a/element.js?cb=googleTranslateElementInit';
    script.async = true;
    document.body.appendChild(script);
  }, []);

  return (
    <div ref={hostRef} className={styles.host}>
      <div id={ELEMENT_ID} />
    </div>
  );
}

export default function GoogleTranslate(): JSX.Element {
  return (
    <BrowserOnly fallback={<span className={styles.fallback}>Translate</span>}>
      {() => <GoogleTranslateInner />}
    </BrowserOnly>
  );
}
