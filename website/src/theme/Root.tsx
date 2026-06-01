import React from 'react';
import Head from '@docusaurus/Head';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import Root from '@theme-original/Root';
import GoogleTranslate from '@site/src/components/GoogleTranslate';
import {
  softwareApplicationJsonLd,
  webSiteJsonLd,
} from '@site/src/seo/siteSeo';

export default function RootWrapper(props: React.ComponentProps<typeof Root>): JSX.Element {
  const {siteConfig} = useDocusaurusContext();
  const siteRoot = `${siteConfig.url}${siteConfig.baseUrl}`.replace(/\/$/, '');
  const globalLd = {
    '@context': 'https://schema.org',
    '@graph': [webSiteJsonLd(siteRoot), softwareApplicationJsonLd(siteRoot)],
  };

  return (
    <>
      <Head>
        <script type="application/ld+json">{JSON.stringify(globalLd)}</script>
      </Head>
      <div className="navbar-google-translate" aria-label="Translate page">
        <GoogleTranslate />
      </div>
      <Root {...props} />
    </>
  );
}
