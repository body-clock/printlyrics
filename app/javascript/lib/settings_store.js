export class SettingsStore {
  constructor(storage = localStorage) {
    this.storage = storage
  }

  get(key, fallback) {
    try {
      return this.storage.getItem(key) || fallback
    } catch {
      return fallback
    }
  }

  set(key, value) {
    try {
      this.storage.setItem(key, value)
    } catch {
      // Degraded mode — controls still work when storage is unavailable.
    }
  }
}
