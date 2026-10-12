import { useEffect, useRef, useState } from 'react';
import QRCode from 'qrcode';
import type { Song } from '../types';
import { linkHostLabel, searchLink, type SearchProvider } from '../lib/links';
import { useAudioFiles } from './audioFiles';
import { Dialog } from './Dialog';

interface Props {
  song: Song;
  searchProvider: SearchProvider;
  revealed: boolean;
}

export function Playback({ song, searchProvider, revealed }: Props) {
  if (song.fileName) return <LocalAudio key={song.id} song={song} />;
  return <LinkPlayback key={song.id} song={song} searchProvider={searchProvider} revealed={revealed} />;
}

function fmt(sec: number): string {
  if (!Number.isFinite(sec)) return '0:00';
  const m = Math.floor(sec / 60);
  const s = Math.floor(sec % 60);
  return `${m}:${String(s).padStart(2, '0')}`;
}

/** Spielt eine lokal ausgewählte Datei ab, ohne Titel/Interpret/Dateinamen anzuzeigen. */
function LocalAudio({ song }: { song: Song }) {
  const audioFiles = useAudioFiles();
  const file = song.fileName ? audioFiles.files.get(song.fileName) : undefined;
  const ref = useRef<HTMLAudioElement>(null);
  const [url, setUrl] = useState<string | null>(null);
  const [playing, setPlaying] = useState(false);
  const [time, setTime] = useState(0);
  const [duration, setDuration] = useState(0);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!file) return;
    const u = URL.createObjectURL(file);
    setUrl(u);
    return () => URL.revokeObjectURL(u);
  }, [file]);

  useEffect(() => {
    // Neutrale Metadaten, damit Sperrbildschirm/Benachrichtigung nicht den Dateinamen verraten.
    if ('mediaSession' in navigator && typeof MediaMetadata !== 'undefined') {
      navigator.mediaSession.metadata = new MediaMetadata({ title: 'Rätsel-Song', artist: 'Jahrgang' });
    }
    return () => ref.current?.pause();
  }, []);

  if (!file) {
    return (
      <div className="playback playback--missing">
        <p>Die Audiodatei für diesen Song ist in diesem Tab nicht geladen.</p>
        <label className="file-drop file-drop--inline">
          <input type="file" multiple accept="audio/*,.mp3,.m4a,.ogg,.opus,.flac,.wav" onChange={(e) => e.target.files && audioFiles.register([...e.target.files])} />
          <span>Audiodateien erneut auswählen …</span>
        </label>
      </div>
    );
  }

  const toggle = async () => {
    const el = ref.current;
    if (!el) return;
    try {
      if (el.paused) await el.play();
      else el.pause();
      setError(null);
    } catch {
      setError('Wiedergabe nicht möglich – dieses Dateiformat wird vom Browser evtl. nicht unterstützt.');
    }
  };

  return (
    <div className="playback">
      {url && (
        <audio
          ref={ref}
          src={url}
          preload="metadata"
          onPlay={() => setPlaying(true)}
          onPause={() => setPlaying(false)}
          onEnded={() => setPlaying(false)}
          onTimeUpdate={(e) => setTime(e.currentTarget.currentTime)}
          onLoadedMetadata={(e) => setDuration(e.currentTarget.duration)}
          onError={() => setError('Die Datei konnte nicht gelesen werden.')}
        />
      )}
      <button type="button" className={`play-btn${playing ? ' play-btn--playing' : ''}`} onClick={toggle} aria-label={playing ? 'Pause' : 'Abspielen'}>
        <span aria-hidden="true">{playing ? '❚❚' : '▶'}</span>
      </button>
      <div className="playback__progress">
        <input
          type="range"
          min={0}
          max={duration || 0}
          step={1}
          value={Math.min(time, duration || 0)}
          aria-label="Position im Song"
          aria-valuetext={`${fmt(time)} von ${fmt(duration)}`}
          onChange={(e) => {
            if (ref.current) ref.current.currentTime = +e.target.value;
          }}
        />
        <span className="muted small">
          {fmt(time)} / {fmt(duration)}
        </span>
      </div>
      {error && <p className="warn-text small" role="alert">{error}</p>}
    </div>
  );
}

function LinkPlayback({ song, searchProvider, revealed }: Props) {
  const link = song.link ?? searchLink(searchProvider, song.artist, song.title);
  const isSearch = !song.link;
  const [qr, setQr] = useState<string | null>(null);
  const [showQr, setShowQr] = useState(false);

  useEffect(() => {
    if (!showQr || !link) return;
    let active = true;
    QRCode.toDataURL(link, { margin: 1, width: 280, errorCorrectionLevel: 'M' })
      .then((d) => active && setQr(d))
      .catch(() => active && setQr(null));
    return () => {
      active = false;
    };
  }, [showQr, link]);

  if (!link) {
    return (
      <div className="playback playback--missing">
        <p>
          Für diesen Song gibt es keinen Link. Spielt ihn in einer beliebigen Musik-App ab – die Spielleitung kann Titel und
          Interpret unter „Spielleitung: Song anzeigen“ nachsehen.
        </p>
      </div>
    );
  }

  const label = linkHostLabel(link);
  return (
    <div className="playback playback--link">
      <div className="row wrap">
        {/* Button statt <a>, damit der Link (bei Suchlinks inkl. Titel) beim Überfahren nicht in der Statusleiste erscheint. */}
        <button type="button" className="btn btn--primary btn--large" onClick={() => window.open(link, '_blank', 'noopener,noreferrer')}>
          ▶ {isSearch ? `In ${label} suchen & abspielen` : `In ${label} öffnen`}
          <span className="sr-only"> (öffnet in neuem Fenster)</span>
        </button>
        <button type="button" className="btn btn--secondary" onClick={() => setShowQr(true)}>
          QR-Code für zweites Gerät
        </button>
      </div>
      {!revealed && (
        <p className="muted small">
          Die Musik-App zeigt den Titel an. Legt das Gerät verdeckt hin oder lasst eine Person, die gerade nicht rät, den Song
          starten. {isSearch && 'Bei der Suche bitte das Original (nicht Remix/Live) auswählen.'}
        </p>
      )}
      <Dialog
        open={showQr}
        title="Auf einem zweiten Gerät abspielen"
        onClose={() => setShowQr(false)}
        actions={
          <button type="button" className="btn btn--primary" onClick={() => setShowQr(false)}>
            Fertig
          </button>
        }
      >
        <p>Mit der Kamera des Abspielgeräts scannen. Das Gerät danach verdeckt hinlegen.</p>
        <div className="qr">{qr ? <img src={qr} alt="QR-Code mit dem Abspiel-Link" width={280} height={280} /> : <p>Erzeuge QR-Code …</p>}</div>
      </Dialog>
    </div>
  );
}
