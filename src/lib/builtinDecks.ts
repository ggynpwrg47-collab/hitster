import type { Deck } from '../types';
import { deckFromData } from './deckFile';

/**
 * Fest eingebaute Listen: Jede Datei „src/decks/*.jahrgang.json“ wird beim Build in die App gepackt
 * und steht dann auf jedem Gerät zur Verfügung (z. B. am Handy über die Netlify-Adresse).
 */
const files = import.meta.glob<unknown>('../decks/*.json', { eager: true, import: 'default' });

export function loadBuiltinDecks(): Deck[] {
  const decks: Deck[] = [];
  for (const [path, data] of Object.entries(files)) {
    const fileName = path.split('/').pop()!.replace(/\.json$/, '').replace(/\.jahrgang$/, '');
    const deck = deckFromData(data, { id: `builtin_${fileName.replace(/[^A-Za-z0-9_-]/g, '_')}`, kind: 'builtin' });
    if (deck) decks.push({ ...deck, createdAt: 0, updatedAt: 0 });
    else console.warn(`Eingebaute Liste „${path}“ ist kein gültiges Jahrgang-Format und wurde übersprungen.`);
  }
  return decks.sort((a, b) => a.name.localeCompare(b.name, 'de'));
}
