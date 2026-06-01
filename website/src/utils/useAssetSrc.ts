import useBaseUrl from '@docusaurus/useBaseUrl';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';

/** Resolves static / webpack asset paths with baseUrl. */
export function useAssetSrc(path: string): string {
  const {siteConfig} = useDocusaurusContext();
  const baseUrl = siteConfig.baseUrl.endsWith('/')
    ? siteConfig.baseUrl
    : `${siteConfig.baseUrl}/`;

  if (!path) return path;
  if (path.startsWith('http://') || path.startsWith('https://')) return path;
  if (path.startsWith(baseUrl)) return path;

  const normalized = path.startsWith('/') ? path : `/${path}`;
  return useBaseUrl(normalized);
}
