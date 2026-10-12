import { describe, expect, it } from 'vitest';
import type { GameSettings, GameState, PlayerSetup, Song } from '../types';
import { correctGaps, createGame, DEFAULT_SETTINGS, gameReducer, insertSorted, vetoBlockReason, yearPoints } from './game';

function song(id: string, year: number | null): Song {
  return { id, title: `T${id}`, artist: `A${id}`, year, precision: 'year', yearSource: 'manual', warnings: [], confirmed: true };
}

const players: PlayerSetup[] = [
  { id: 'p1', name: 'Anna', color: '#000' },
  { id: 'p2', name: 'Ben', color: '#111' },
  { id: 'p3', name: 'Cem', color: '#222' },
];

/** Baut ein Spiel mit festgelegter Reihenfolge (shuffle: false): Startkarten p1..p3, dann Zugkarten. */
function setup(years: number[], settings: Partial<GameSettings> = {}): GameState {
  const songs = years.map((y, i) => song(String(i), y));
  return createGame(songs, players, { ...DEFAULT_SETTINGS, shuffle: false, ...settings }, 1, 'd');
}

function run(state: GameState, ...actions: Parameters<typeof gameReducer>[1][]): GameState {
  return actions.reduce(gameReducer, state);
}

describe('Zeitleisten-Helfer', () => {
  it('correctGaps berücksichtigt gleiche Jahre', () => {
    const tl = [{ songId: 'a', year: 1980 }, { songId: 'b', year: 1990 }];
    expect(correctGaps(tl, 1985)).toEqual([1]);
    expect(correctGaps(tl, 1970)).toEqual([0]);
    expect(correctGaps(tl, 1990)).toEqual([1, 2]);
    expect(correctGaps([], 2000)).toEqual([0]);
  });
  it('insertSorted hält die Chronologie', () => {
    const tl = insertSorted([{ songId: 'a', year: 1980 }, { songId: 'b', year: 1990 }], { songId: 'c', year: 1985 });
    expect(tl.map((c) => c.year)).toEqual([1980, 1985, 1990]);
  });
  it('yearPoints', () => {
    expect([0, 1, 2, 3, 4].map(yearPoints)).toEqual([3, 2, 1, 1, 0]);
  });
});

describe('Spielstart', () => {
  it('verteilt Startkarten und Chips', () => {
    const g = setup([1970, 1980, 1990, 2000, 2010], { vetoStartChips: 3 });
    expect(g.players.map((p) => p.timeline.length)).toEqual([1, 1, 1]);
    expect(g.players.every((p) => p.chips === 3)).toBe(true);
    expect(g.turn?.songId).toBe('3');
    expect(g.drawPile).toEqual(['4']);
  });
  it('ohne Veto-Chips startet jeder mit 0 Chips', () => {
    const g = setup([1970, 1980, 1990, 2000], { vetoEnabled: false, vetoStartChips: 3 });
    expect(g.players.every((p) => p.chips === 0)).toBe(true);
  });
  it('ignoriert Songs ohne Jahr und verlangt genügend Songs', () => {
    expect(() => createGame([song('a', 1990), song('b', null)], players, DEFAULT_SETTINGS, 1, 'd')).toThrow(/Zu wenige/);
  });
  it('mischt reproduzierbar', () => {
    const songs = Array.from({ length: 20 }, (_, i) => song(String(i), 1960 + i));
    const a = createGame(songs, players, DEFAULT_SETTINGS, 42, 'd');
    const b = createGame(songs, players, DEFAULT_SETTINGS, 42, 'd');
    expect(a.drawPile).toEqual(b.drawPile);
    expect(a.drawPile).not.toEqual(songs.slice(4).map((s) => s.id));
  });
});

describe('Zug im Zeitleisten-Modus', () => {
  // Anna hat 1970 auf der Zeitleiste, Zugkarte ist 2000.
  it('richtige Platzierung gibt Karte und Punkt', () => {
    let g = setup([1970, 1980, 1990, 2000, 2010]);
    g = run(g, { type: 'guess', value: 1 }, { type: 'confirm' }, { type: 'reveal' });
    expect(g.turn?.result).toMatchObject({ correct: true, winnerId: 'p1', points: 1 });
    expect(g.players[0].timeline.map((c) => c.year)).toEqual([1970, 2000]);
    expect(g.players[0].score).toBe(1);
  });
  it('falsche Platzierung ohne Veto verwirft die Karte', () => {
    let g = setup([1970, 1980, 1990, 2000, 2010]);
    g = run(g, { type: 'guess', value: 0 }, { type: 'confirm' }, { type: 'reveal' });
    expect(g.turn?.result).toMatchObject({ correct: false, winnerId: null });
    expect(g.players[0].timeline).toHaveLength(1);
  });
  it('Raten ist nach dem Bestätigen gesperrt, außer es gibt noch kein Veto', () => {
    let g = setup([1970, 1980, 1990, 2000, 2010]);
    g = run(g, { type: 'guess', value: 0 }, { type: 'confirm' }, { type: 'guess', value: 1 });
    expect(g.turn?.guess).toBe(0);
    g = run(g, { type: 'unlock' }, { type: 'guess', value: 1 });
    expect(g.turn?.guess).toBe(1);
  });
});

describe('Veto-Chips', () => {
  const locked = () => run(setup([1970, 1980, 1990, 2000, 2010]), { type: 'guess', value: 0 }, { type: 'confirm' });

  it('Veto nur nach Bestätigung und vor dem Aufdecken', () => {
    const g = setup([1970, 1980, 1990, 2000, 2010]);
    expect(vetoBlockReason(g, 'p2', 1)).toMatch(/bestätigt/);
    const revealed = run(locked(), { type: 'reveal' });
    expect(vetoBlockReason(revealed, 'p2', 1)).not.toBeNull();
  });

  it('nicht auf der Position des aktiven Spielers, nicht vom aktiven Spieler selbst', () => {
    const g = locked();
    expect(vetoBlockReason(g, 'p2', 0)).toMatch(/aktiven Spielers/);
    expect(vetoBlockReason(g, 'p1', 1)).toMatch(/gegen sich selbst/);
  });

  it('nur ein Chip pro Position und ein Veto pro Spieler und Zug', () => {
    let g = run(locked(), { type: 'veto', playerId: 'p2', value: 1 });
    expect(vetoBlockReason(g, 'p3', 1)).toMatch(/bereits ein Veto-Chip/);
    expect(vetoBlockReason(g, 'p2', 1)).toMatch(/bereits ein Veto gesetzt/);
    const before = g;
    g = run(g, { type: 'veto', playerId: 'p3', value: 1 });
    expect(g).toBe(before); // abgelehnt, nichts verändert
  });

  it('verbraucht Chips und verhindert negative Chipstände', () => {
    let g = setup([1970, 1980, 1990, 2000, 2010, 2020, 1960], { vetoStartChips: 1 });
    g = run(g, { type: 'guess', value: 0 }, { type: 'confirm' }, { type: 'veto', playerId: 'p2', value: 1 });
    expect(g.players[1].chips).toBe(0);
    g = run(g, { type: 'reveal' }, { type: 'next' }, { type: 'guess', value: 0 }, { type: 'confirm' });
    // Ben ist jetzt aktiv; Anna hat noch 1 Chip, Ben 0
    expect(vetoBlockReason(g, 'p1', 1)).toBeNull();
    g = run(g, { type: 'reveal' }, { type: 'next' }, { type: 'guess', value: 0 }, { type: 'confirm' });
    // Cem aktiv; Ben hat 0 Chips
    expect(vetoBlockReason(g, 'p2', 1)).toMatch(/keine Veto-Chips/);
    const before = g;
    expect(run(g, { type: 'veto', playerId: 'p2', value: 1 })).toBe(before);
  });

  it('erfolgreiches Veto: Herausforderer ordnet die Karte bei sich ein', () => {
    let g = run(locked(), { type: 'veto', playerId: 'p2', value: 1 });
    g = run(g, { type: 'reveal' });
    expect(g.turn?.result).toMatchObject({ correct: false, viaVeto: true, winnerId: 'p2' });
    expect(g.players[0].timeline).toHaveLength(1);
    // Ben hatte 1980 – die 2000er-Karte wird bei ihm chronologisch eingeordnet
    expect(g.players[1].timeline.map((c) => c.year)).toEqual([1980, 2000]);
    expect(g.players[1].score).toBe(1);
    expect(g.players[1].chips).toBe(DEFAULT_SETTINGS.vetoStartChips - 1);
  });

  it('wenn der aktive Spieler richtig liegt, verfällt das Veto', () => {
    let g = setup([1970, 1980, 1990, 2000, 2010]);
    g = run(g, { type: 'guess', value: 1 }, { type: 'confirm' }, { type: 'veto', playerId: 'p2', value: 0 }, { type: 'reveal' });
    expect(g.turn?.result?.winnerId).toBe('p1');
    expect(g.players[1].chips).toBe(DEFAULT_SETTINGS.vetoStartChips - 1);
    expect(g.players[1].timeline).toHaveLength(1);
  });

  it('nach einem Veto kann der aktive Spieler seine Wahl nicht mehr ändern', () => {
    const g = run(locked(), { type: 'veto', playerId: 'p2', value: 1 }, { type: 'unlock' });
    expect(g.turn?.phase).toBe('locked');
  });

  it('Zurückziehen und Überspringen erstatten Chips', () => {
    let g = run(locked(), { type: 'veto', playerId: 'p2', value: 1 }, { type: 'withdrawVeto', playerId: 'p2' });
    expect(g.players[1].chips).toBe(DEFAULT_SETTINGS.vetoStartChips);
    expect(g.turn?.vetoes).toEqual([]);
    g = run(g, { type: 'veto', playerId: 'p3', value: 1 }, { type: 'skip' });
    expect(g.players[2].chips).toBe(DEFAULT_SETTINGS.vetoStartChips);
    expect(g.turn).toMatchObject({ songId: '4', phase: 'guessing', vetoes: [] });
    expect(g.activeIndex).toBe(0);
  });

  it('Neustart setzt Chips, Punkte und Zeitleisten zurück', () => {
    let g = run(locked(), { type: 'veto', playerId: 'p2', value: 1 }, { type: 'reveal' });
    g = run(g, { type: 'restart', seed: 7 });
    expect(g.players.every((p) => p.chips === DEFAULT_SETTINGS.vetoStartChips && p.score === 0 && p.timeline.length === 1)).toBe(true);
    expect(g.round).toBe(1);
    expect(g.log).toEqual([]);
  });

  it('ausgeschaltete Veto-Chips werden blockiert', () => {
    const g = run(setup([1970, 1980, 1990, 2000], { vetoEnabled: false }), { type: 'guess', value: 0 }, { type: 'confirm' });
    expect(vetoBlockReason(g, 'p2', 1)).toMatch(/ausgeschaltet/);
  });
});

describe('Rundenablauf', () => {
  it('endet nach der eingestellten Rundenzahl', () => {
    const years = Array.from({ length: 20 }, (_, i) => 1960 + i);
    let g = setup(years, { rounds: 1 });
    for (let i = 0; i < 3; i++) g = run(g, { type: 'guess', value: 0 }, { type: 'confirm' }, { type: 'reveal' }, { type: 'next' });
    expect(g.status).toBe('finished');
    expect(g.finishReason).toBe('rounds');
  });
  it('endet, wenn der Stapel leer ist', () => {
    let g = setup([1970, 1980, 1990, 2000]);
    g = run(g, { type: 'guess', value: 0 }, { type: 'confirm' }, { type: 'reveal' }, { type: 'next' });
    expect(g.status).toBe('finished');
    expect(g.finishReason).toBe('deck-empty');
  });
  it('endet bei erreichter Zielkartenzahl', () => {
    const years = Array.from({ length: 20 }, (_, i) => 1960 + i);
    let g = setup(years, { targetCards: 2, rounds: 10 });
    g = run(g, { type: 'guess', value: 1 }, { type: 'confirm' }, { type: 'reveal' }, { type: 'next' });
    expect(g.finishReason).toBe('target');
  });
  it('Überspringen ist abschaltbar', () => {
    const g = setup([1970, 1980, 1990, 2000, 2010], { allowSkip: false });
    expect(run(g, { type: 'skip' })).toBe(g);
  });
});

describe('Jahres-Modus', () => {
  const yearGame = () => createGame([song('a', 1985), song('b', 1990)], players, { ...DEFAULT_SETTINGS, mode: 'year', shuffle: false }, 1, 'd');

  it('vergibt Punkte nach Abstand', () => {
    const g = run(yearGame(), { type: 'guess', value: 1986 }, { type: 'confirm' }, { type: 'reveal' });
    expect(g.turn?.result).toMatchObject({ points: 2, winnerId: 'p1', distance: 1 });
    expect(g.players[0].score).toBe(2);
  });
  it('Veto mit näherer Schätzung übernimmt die Punkte', () => {
    const g = run(yearGame(), { type: 'guess', value: 1988 }, { type: 'confirm' }, { type: 'veto', playerId: 'p2', value: 1985 }, { type: 'veto', playerId: 'p3', value: 1984 }, { type: 'reveal' });
    expect(g.turn?.result).toMatchObject({ viaVeto: true, winnerId: 'p2', points: 3 });
    expect(g.players[0].score).toBe(0);
    expect(g.players[1].score).toBe(3);
    expect(g.players[2].score).toBe(0);
  });
  it('Veto darf nicht dasselbe Jahr wie der aktive Spieler nennen', () => {
    const g = run(yearGame(), { type: 'guess', value: 1988 }, { type: 'confirm' });
    expect(vetoBlockReason(g, 'p2', 1988)).toMatch(/aktiven Spielers/);
  });
});
