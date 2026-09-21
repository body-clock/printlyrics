function resolveStorage(name) {
  try {
    return window[name]
  } catch {
    // Reading the property itself throws when the browser blocks storage.
    return null
  }
}

export class SettingsStore {
  constructor(storage = resolveStorage("localStorage")) {
    this.storage = storage
  }

  get(key, fallback) {
    try {
      return this.storage?.getItem(key) || fallback
    } catch {
      return fallback
    }
  }

  set(key, value) {
    try {
      this.storage?.setItem(key, value)
    } catch {
      // Degraded mode — controls still work when storage is unavailable.
    }
  }

  remove(key) {
    try {
      this.storage?.removeItem(key)
    } catch {
      // Degraded mode — there is nothing to clear and callers still work.
    }
  }
}

// Telemetry keeps its counters in session storage, so it needs the same
// degradation guarantees the preview preferences get.
export function sessionStore() {
  return new SettingsStore(resolveStorage("sessionStorage"))
}
