/** Hilfsfunktionen für Abspiel-Links. Es werden nur normale Web-Links geöffnet – keine API-Aufrufe. */

export type SearchProvider = 'spotify' | 'youtube' | 'none';

/** Akzeptiert nur http(s)-Links; wandelt "spotify:track:ID" in einen normalen Web-Link um. */
export function normalizeLink(raw: string | undefined | null): string | undefined {
  if (!raw) return undefined;
  const s = raw.trim();
  if (!s) return undefined;
  const uri = s.match(/^spotify:(track|episode):([A-Za-z0-9]{10,40})$/);
  if (uri) return `https://open.spotify.com/${uri[1]}/${uri[2]}`;
  try {
    const url = new URL(s);
    if (url.protocol !== 'https:' && url.protocol !== 'http:') return undefined;
    if (url.protocol === 'http:') url.protocol = 'https:';
    return url.toString();
  } catch {
    return undefined;
  }
}

export function searchLink(provider: SearchProvider, artist: string, title: string): string | undefined {
  const q = `${artist} ${title}`.trim();
  if (!q) return undefined;
  if (provider === 'spotify') return `https://open.spotify.com/search/${encodeURIComponent(q)}`;
  if (provider === 'youtube') return `https://www.youtube.com/results?search_query=${encodeURIComponent(q)}`;
  return undefined;
}

export function linkHostLabel(link: string): string {
  try {
    const host = new URL(link).hostname.replace(/^www\./, '');
    if (host.endsWith('spotify.com')) return 'Spotify';
    if (host.endsWith('youtube.com') || host === 'youtu.be') return 'YouTube';
    if (host.endsWith('music.apple.com')) return 'Apple Music';
    if (host.endsWith('deezer.com')) return 'Deezer';
    if (host.endsWith('tidal.com')) return 'TIDAL';
    if (host.endsWith('bandcamp.com')) return 'Bandcamp';
    if (host.endsWith('soundcloud.com')) return 'SoundCloud';
    return host;
  } catch {
    return 'Link';
  }
}
