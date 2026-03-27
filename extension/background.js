// TabPilot Time Tracker — Chrome Extension
// Tracks active dwell time per tab/URL using chrome.tabs and chrome.idle APIs.
// Sends timing data to the TabPilot macOS app via Native Messaging.

const NATIVE_HOST = "com.tabpilot.timetracker";
const SYNC_INTERVAL_MS = 30_000;   // send accumulated data every 30s
const IDLE_THRESHOLD = "idle";     // pause tracking when browser is idle

// ── In-memory state ──────────────────────────────────────────────
// Per-tab timing: tabId → { url, domain, startTime, accumulatedMs }
const tabState = new Map();

// Aggregate per-domain time: domain → totalMs (today only, reset daily)
let domainTime = {};

// Currently active tab info
let activeTabId = null;
let activeWindowId = null;
let trackingPaused = false;

// ── Helpers ──────────────────────────────────────────────────────

function getDomain(url) {
  try {
    const host = new URL(url).hostname;
    return host.replace(/^www\./, "");
  } catch {
    return "unknown";
  }
}

function todayKey() {
  return new Date().toISOString().slice(0, 10); // "2026-03-26"
}

function now() {
  return Date.now();
}

// ── Core tracking ────────────────────────────────────────────────

function startTracking(tabId, url, options = {}) {
  const { startImmediately = false } = options;
  if (!url || url.startsWith("chrome://") || url.startsWith("chrome-extension://")) return;

  const domain = getDomain(url);
  tabState.set(tabId, {
    url,
    domain,
    startTime: startImmediately && !trackingPaused ? now() : null,
    accumulatedMs: tabState.get(tabId)?.accumulatedMs || 0,
  });
}

function stopTracking(tabId) {
  const state = tabState.get(tabId);
  if (!state || !state.startTime) return;

  const elapsed = now() - state.startTime;
  state.accumulatedMs += elapsed;
  state.startTime = null;

  // Add to domain aggregate
  domainTime[state.domain] = (domainTime[state.domain] || 0) + elapsed;
}

function pauseAll() {
  for (const [tabId] of tabState) {
    stopTracking(tabId);
  }
  trackingPaused = true;
}

function resumeActiveTab() {
  trackingPaused = false;
  if (activeTabId != null) {
    const state = tabState.get(activeTabId);
    if (state) {
      state.startTime = now();
    }
  }
}

// ── Chrome event listeners ───────────────────────────────────────

// Tab activated (user switched tabs within a window)
chrome.tabs.onActivated.addListener(({ tabId, windowId }) => {
  if (activeTabId != null) {
    stopTracking(activeTabId);
  }
  activeTabId = tabId;
  activeWindowId = windowId;

  if (!trackingPaused) {
    const state = tabState.get(tabId);
    if (state) {
      state.startTime = now();
    }
  }
});

// Window focus changed (user switched to a different Chrome window or left Chrome)
chrome.windows.onFocusChanged.addListener((windowId) => {
  if (windowId === chrome.windows.WINDOW_ID_NONE) {
    // Chrome lost focus entirely
    if (activeTabId != null) {
      stopTracking(activeTabId);
    }
    return;
  }

  // Get the active tab in the newly focused window
  chrome.tabs.query({ active: true, windowId }, (tabs) => {
    if (activeTabId != null) {
      stopTracking(activeTabId);
    }
    if (tabs.length > 0) {
      activeTabId = tabs[0].id;
      activeWindowId = windowId;
      if (!trackingPaused) {
        const state = tabState.get(activeTabId);
        if (state) {
          state.startTime = now();
        }
      }
    }
  });
});

// Tab updated (navigation, URL change)
chrome.tabs.onUpdated.addListener((tabId, changeInfo, tab) => {
  if (changeInfo.url) {
    // URL changed — stop tracking old URL, start tracking new one
    stopTracking(tabId);
    startTracking(tabId, changeInfo.url);

    // If this is the active tab, restart its timer
    if (tabId === activeTabId && !trackingPaused) {
      const state = tabState.get(tabId);
      if (state) {
        state.startTime = now();
      }
    }
  } else if (changeInfo.status === "complete" && !tabState.has(tabId)) {
    // New tab loaded
    startTracking(tabId, tab.url);
  }
});

// Tab created
chrome.tabs.onCreated.addListener((tab) => {
  if (tab.url) {
    startTracking(tab.id, tab.url, { startImmediately: tab.active === true });
  }
});

// Tab removed
chrome.tabs.onRemoved.addListener((tabId) => {
  stopTracking(tabId);
  tabState.delete(tabId);
});

// Idle state detection
chrome.idle.onStateChanged.addListener((state) => {
  if (state === IDLE_THRESHOLD || state === "locked") {
    pauseAll();
  } else if (state === "active") {
    resumeActiveTab();
  }
});

// ── Initialize on startup ───────────────────────────────────────

chrome.runtime.onStartup.addListener(initialize);
chrome.runtime.onInstalled.addListener(initialize);

function initialize() {
  // Load persisted domain time for today
  const key = `dt_${todayKey()}`;
  chrome.storage.local.get([key], (result) => {
    domainTime = result[key] || {};
  });

  // Discover all existing tabs and current active tab
  chrome.tabs.query({}, (tabs) => {
    for (const tab of tabs) {
      if (tab.url) {
        startTracking(tab.id, tab.url, { startImmediately: false });
      }
    }

    // Find the actual active tab
    chrome.tabs.query({ active: true, lastFocusedWindow: true }, (activeTabs) => {
      if (activeTabs.length > 0) {
        activeTabId = activeTabs[0].id;
        activeWindowId = activeTabs[0].windowId;
        if (!trackingPaused) {
          const state = tabState.get(activeTabId);
          if (state) {
            state.startTime = now();
          }
        }
      }
    });
  });

  // Set idle detection to 60s
  chrome.idle.setDetectionInterval(60);
}

// ── Native Messaging: sync to TabPilot app ───────────────────────

let nativePort = null;

function connectNative() {
  try {
    nativePort = chrome.runtime.connectNative(NATIVE_HOST);
    nativePort.onDisconnect.addListener(() => {
      nativePort = null;
    });
  } catch (e) {
    // Native host not installed — silently fail
    nativePort = null;
  }
}

function syncToNative() {
  // Flush current tab timers
  for (const [tabId] of tabState) {
    stopTracking(tabId);
  }

  // Restart timers for active tab
  if (activeTabId != null && !trackingPaused) {
    const state = tabState.get(activeTabId);
    if (state) {
      state.startTime = now();
    }
  }

  const payload = {
    type: "tab_time_update",
    date: todayKey(),
    timestamp: now(),
    domainTime: { ...domainTime },
    activeTabId,
    tabs: {},
  };

  // Per-tab detail (for duplicate time analysis)
  for (const [tabId, state] of tabState) {
    payload.tabs[tabId] = {
      url: state.url,
      domain: state.domain,
      totalMs: state.accumulatedMs,
    };
  }

  if (!nativePort) {
    connectNative();
  }

  if (nativePort) {
    try {
      nativePort.postMessage(payload);
    } catch {
      nativePort = null;
    }
  }

  // Also persist locally as backup
  const key = `dt_${todayKey()}`;
  chrome.storage.local.set({ [key]: domainTime });

  // Restart timers
  if (activeTabId != null && !trackingPaused) {
    const state = tabState.get(activeTabId);
    if (state) {
      state.startTime = now();
    }
  }
}

// Periodic sync
setInterval(syncToNative, SYNC_INTERVAL_MS);

// Also sync on window close / before unload
chrome.windows.onRemoved.addListener(syncToNative);
