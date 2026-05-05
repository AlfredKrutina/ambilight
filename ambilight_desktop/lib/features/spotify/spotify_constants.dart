/// Zaregistruj stejné URI v [Spotify Developer Dashboard](https://developer.spotify.com/dashboard).
const kSpotifyRedirectUri = 'http://127.0.0.1:8767/callback';

/// Minimální scopes pro aktuální skladbu + obrázek alba.
const kSpotifyScopes = [
  'user-read-playback-state',
  'user-read-currently-playing',
];
