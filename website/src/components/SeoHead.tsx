import Head from '@docusaurus/Head';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import {
  DEFAULT_KEYWORDS,
  SOCIAL_CARD_PATH,
  absoluteUrl,
} from '@site/src/seo/siteSeo';

type Props = {
  title: string;
  description: string;
  /** Path under baseUrl, e.g. `/` or `/docs/intro` */
  pathname?: string;
  /** Extra JSON-LD objects merged into @graph on this page */
  jsonLd?: Record<string, unknown>[];
  noindex?: boolean;
};

export default function SeoHead({
  title,
  description,
  pathname = '/',
  jsonLd = [],
  noindex = false,
}: Props): JSX.Element {
  const {siteConfig} = useDocusaurusContext();
  const siteUrl = siteConfig.url + siteConfig.baseUrl.replace(/\/$/, '');
  const canonical = absoluteUrl(siteConfig.url, `${siteConfig.baseUrl}${pathname}`.replace(/\/+/g, '/'));
  const ogImage = absoluteUrl(siteConfig.url, `${siteConfig.baseUrl}${SOCIAL_CARD_PATH}`.replace(/\/+/g, '/'));
  const keywords = DEFAULT_KEYWORDS;
  const fullTitle = title.includes('VeltoKit') ? title : `${title} | VeltoKit`;

  const graph = jsonLd.length > 0 ? {'@graph': jsonLd} : null;

  return (
    <Head>
      <title>{fullTitle}</title>
      <meta name="description" content={description} />
      <meta name="keywords" content={keywords} />
      <link rel="canonical" href={canonical} />
      {noindex ? <meta name="robots" content="noindex, nofollow" /> : null}

      <meta property="og:type" content="website" />
      <meta property="og:site_name" content="VeltoKit" />
      <meta property="og:title" content={fullTitle} />
      <meta property="og:description" content={description} />
      <meta property="og:url" content={canonical} />
      <meta property="og:image" content={ogImage} />
      <meta property="og:image:width" content="1200" />
      <meta property="og:image:height" content="630" />
      <meta property="og:locale" content="en_US" />

      <meta name="twitter:card" content="summary_large_image" />
      <meta name="twitter:title" content={fullTitle} />
      <meta name="twitter:description" content={description} />
      <meta name="twitter:image" content={ogImage} />

      <meta name="apple-mobile-web-app-title" content="VeltoKit" />
      <meta name="application-name" content="VeltoKit" />

      {graph ? (
        <script type="application/ld+json">{JSON.stringify(graph)}</script>
      ) : null}
    </Head>
  );
}
