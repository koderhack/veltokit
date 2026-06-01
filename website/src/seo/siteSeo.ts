/** Shared SEO constants — keep in sync with docusaurus.config.ts baseUrl. */

export const SITE_NAME = 'VeltoKit';
export const SITE_TAGLINE =
  'Swift SDK for BLE motion input — GameInput every frame for iOS games';

export const DEFAULT_KEYWORDS = [
  'VeltoKit',
  'Swift motion SDK',
  'iOS BLE game controller',
  'GameInput',
  'MotionSDK',
  'BLE gyroscope',
  'cap controller',
  'Swift game development',
  'iOS game input',
  'gesture throw',
  'paddle mode',
  'TrikiInputAdapter',
  'veltokit',
].join(', ');

export const SOCIAL_CARD_PATH = '/img/veltokit-social-card.svg';

export function absoluteUrl(siteUrl: string, path: string): string {
  const base = siteUrl.replace(/\/$/, '');
  const p = path.startsWith('/') ? path : `/${path}`;
  return `${base}${p}`;
}

export function webSiteJsonLd(siteUrl: string) {
  return {
    '@context': 'https://schema.org',
    '@type': 'WebSite',
    name: SITE_NAME,
    url: siteUrl,
    description: SITE_TAGLINE,
    inLanguage: 'en',
    publisher: {
      '@type': 'Organization',
      name: 'Koderteam',
      url: 'https://github.com/koderteam',
    },
  };
}

export function softwareApplicationJsonLd(siteUrl: string) {
  return {
    '@context': 'https://schema.org',
    '@type': 'SoftwareApplication',
    name: SITE_NAME,
    applicationCategory: 'DeveloperApplication',
    operatingSystem: 'iOS 16+',
    offers: {
      '@type': 'Offer',
      price: '0',
      priceCurrency: 'USD',
    },
    description: SITE_TAGLINE,
    url: siteUrl,
    softwareHelp: `${siteUrl}/docs/intro`,
    downloadUrl: 'https://github.com/koderteam/veltokit',
    programmingLanguage: 'Swift',
  };
}
