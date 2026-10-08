import { config } from './config.js';

// Flutter's development server selects a free port when no port is specified.
// Production continues to trust only the explicitly configured APP_ORIGIN.
export function isTrustedOrigin(origin) {
  if (typeof origin !== 'string' || !origin) return false;
  if (origin === config.APP_ORIGIN) return true;
  if (config.NODE_ENV !== 'development') return false;
  const match = /^http:\/\/localhost(?::([1-9]\d{0,4}))?$/.exec(origin);
  return match !== null && (!match[1] || Number(match[1]) <= 65535);
}
