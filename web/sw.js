/**
 * ReelTalk Progressive Web App Service Worker
 * Optimized caching strategy for performance and offline support
 * Version: 1.0.5 - Safari offline detection fix
 * 
 * PERFORMANCE OPTIMIZATION:
 * - Install and activate events complete instantly (no event.waitUntil)
 * - All caching and cleanup happens in the background
 * - Resolves Flutter's 4-second prepareServiceWorker timeout issue
 * - Assets are cached opportunistically as they're requested
 * - Network-first for HTML pages to ensure users see latest version
 * - Safari fix: Disabled offline page to prevent false offline detection
 */

const CACHE_VERSION = 'ReelTalk-v1.0.5';
const CACHE_NAME = `${CACHE_VERSION}-assets`;
const DATA_CACHE_NAME = `${CACHE_VERSION}-data`;

// Assets to cache in background (minimal for fast startup)
const PRECACHE_URLS = [
  '/manifest.json',
  '/icons/Icon-192.png'
];

// Cache strategies for different resource types
const CACHE_STRATEGIES = {
  // Cache first, fallback to network (for static assets)
  CACHE_FIRST: 'cache-first',
  
  // Network first, fallback to cache (for API calls)
  NETWORK_FIRST: 'network-first',
  
  // Network only (for real-time data)
  NETWORK_ONLY: 'network-only',
  
  // Stale while revalidate (for images)
  STALE_WHILE_REVALIDATE: 'stale-while-revalidate'
};

// Configuration
const CONFIG = {
  // Maximum age for cached assets (7 days)
  maxAge: 7 * 24 * 60 * 60 * 1000,
  
  // Maximum number of items in data cache
  maxDataCacheSize: 50,
  
  // Network timeout for cache fallback (10 seconds for Safari)
  networkTimeout: 10000,
  
  // Disable offline page - Safari incorrectly detects offline state
  // Better to show cached content than a false offline message
  offlineEnabled: false
};

// ============================================================================
// Installation
// ============================================================================

self.addEventListener('install', (event) => {
  // Skip waiting immediately to activate faster
  self.skipWaiting();
  
  // Don't wait for precaching - do it in the background
  caches.open(CACHE_NAME)
    .then((cache) => {
      // Add assets individually to avoid blocking if one fails
      return Promise.allSettled(
        PRECACHE_URLS.map(url => 
          cache.add(url).catch(err => console.warn(`Failed to cache ${url}:`, err))
        )
      );
    })
    .catch((error) => {
      console.warn('⚠️ Background precaching error:', error);
    });
});

// Listen for skip waiting message from the page
self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
});

// ============================================================================
// Activation
// ============================================================================

self.addEventListener('activate', (event) => {
  // Take control immediately without waiting
  self.clients.claim();
  
  // Clean up old caches in the background (don't block activation)
  caches.keys()
    .then((cacheNames) => {
      // Delete old caches
      return Promise.all(
        cacheNames
          .filter((cacheName) => {
            return cacheName.startsWith('ReelTalk-') && 
                   cacheName !== CACHE_NAME && 
                   cacheName !== DATA_CACHE_NAME;
          })
          .map((cacheName) => {
            return caches.delete(cacheName);
          })
      );
    })
    .catch((error) => {
      console.warn('⚠️ Cache cleanup error:', error);
    });
});

// ============================================================================
// Fetch Handler with Smart Caching
// ============================================================================

self.addEventListener('fetch', (event) => {
  const { request } = event;
  const url = new URL(request.url);
  
  // Determine caching strategy based on request type
  const strategy = getStrategy(url, request);
  
  switch (strategy) {
    case CACHE_STRATEGIES.CACHE_FIRST:
      event.respondWith(cacheFirst(request));
      break;
      
    case CACHE_STRATEGIES.NETWORK_FIRST:
      event.respondWith(networkFirst(request));
      break;
      
    case CACHE_STRATEGIES.NETWORK_ONLY:
      event.respondWith(fetch(request));
      break;
      
    case CACHE_STRATEGIES.STALE_WHILE_REVALIDATE:
      event.respondWith(staleWhileRevalidate(request));
      break;
      
    default:
      event.respondWith(fetch(request));
  }
});

// ============================================================================
// Strategy Selector
// ============================================================================

function getStrategy(url, request) {
  // Network only for API calls that must be fresh
  if (url.pathname.includes('/api/auth') || 
      url.pathname.includes('/api/messages') ||
      url.pathname.includes('/api/notifications')) {
    return CACHE_STRATEGIES.NETWORK_ONLY;
  }
  
  // Network first for other API calls (with cache fallback)
  if (url.pathname.startsWith('/api/')) {
    return CACHE_STRATEGIES.NETWORK_FIRST;
  }
  
  // CRITICAL FIX: Network first for HTML pages to prevent showing stale cached content
  // This ensures users always see the latest version when online
  // Safari fix: Also apply to all navigation requests
  if (request.destination === 'document' ||
      request.mode === 'navigate' ||
      url.pathname === '/' ||
      url.pathname === '/index.html' ||
      url.pathname.endsWith('.html')) {
    return CACHE_STRATEGIES.NETWORK_FIRST;
  }
  
  // Network first for Flutter's main.dart.js to ensure latest app version
  if (url.pathname.includes('main.dart.js') ||
      url.pathname.includes('flutter.js') ||
      url.pathname.includes('flutter_service_worker.js')) {
    return CACHE_STRATEGIES.NETWORK_FIRST;
  }
  
  // Stale while revalidate for images and media
  if (request.destination === 'image' || 
      url.pathname.match(/\.(jpg|jpeg|png|gif|webp|svg|mp4|webm)$/i)) {
    return CACHE_STRATEGIES.STALE_WHILE_REVALIDATE;
  }
  
  // Cache first for static assets (JS, CSS, fonts - these have versioned URLs)
  if (url.pathname.match(/\.(js|css|woff2?|ttf|eot)$/i) ||
      url.pathname.includes('/assets/') ||
      url.pathname.includes('flutter')) {
    return CACHE_STRATEGIES.CACHE_FIRST;
  }
  
  // Default: network first (Safari fix)
  return CACHE_STRATEGIES.NETWORK_FIRST;
}

// ============================================================================
// Caching Strategies Implementation
// ============================================================================

/**
 * Cache First Strategy
 * Try cache first, fallback to network
 */
async function cacheFirst(request) {
  const cachedResponse = await caches.match(request);
  
  if (cachedResponse) {
    // Check if cache is stale
    const cacheDate = new Date(cachedResponse.headers.get('date'));
    const now = new Date();
    
    if (now - cacheDate < CONFIG.maxAge) {
      return cachedResponse;
    }
  }
  
  try {
    const networkResponse = await fetch(request);
    
    // Cache successful responses
    if (networkResponse.ok) {
      const cache = await caches.open(CACHE_NAME);
      cache.put(request, networkResponse.clone());
    }
    
    return networkResponse;
  } catch (error) {
    // Return stale cache if network fails
    if (cachedResponse) {
      return cachedResponse;
    }
    
    // Don't show offline page - just fail
    throw error;
  }
}

/**
 * Network First Strategy
 * Try network first, fallback to cache
 * Safari-specific: Better timeout handling and no false offline pages
 */
async function networkFirst(request) {
  try {
    // Try network with increased timeout for Safari
    const networkResponse = await Promise.race([
      fetch(request),
      new Promise((_, reject) => 
        setTimeout(() => reject(new Error('Network timeout')), CONFIG.networkTimeout)
      )
    ]);
    
    // Cache successful responses (only GET requests)
    if (networkResponse.ok && request.method === 'GET') {
      const cache = await caches.open(DATA_CACHE_NAME);
      cache.put(request, networkResponse.clone());
      
      // Manage cache size
      manageCacheSize(DATA_CACHE_NAME, CONFIG.maxDataCacheSize);
    }
    
    return networkResponse;
  } catch (error) {
    // Always try cache as fallback
    const cachedResponse = await caches.match(request);
    
    if (cachedResponse) {
      return cachedResponse;
    }
    
    // If no cache available, just fail
    throw error;
  }
}

/**
 * Stale While Revalidate Strategy
 * Return cache immediately, update in background
 */
async function staleWhileRevalidate(request) {
  const cachedResponse = await caches.match(request);
  
  const fetchPromise = fetch(request).then(async (networkResponse) => {
    if (networkResponse.ok) {
      try {
        const cache = await caches.open(CACHE_NAME);
        // Clone BEFORE using the response
        await cache.put(request, networkResponse.clone());
      } catch (error) {
        // Silently fail if caching fails
        console.warn('Cache put failed:', error);
      }
    }
    return networkResponse;
  }).catch(() => {
    // Silently fail, we already have cache
  });
  
  // Return cache immediately if available, otherwise wait for network
  return cachedResponse || fetchPromise;
}

// ============================================================================
// Helper Functions
// ============================================================================

/**
 * Manage cache size by removing oldest entries
 */
async function manageCacheSize(cacheName, maxSize) {
  const cache = await caches.open(cacheName);
  const keys = await cache.keys();
  
  if (keys.length > maxSize) {
    // Remove oldest entries (first in, first out)
    const entriesToDelete = keys.slice(0, keys.length - maxSize);
    await Promise.all(entriesToDelete.map(key => cache.delete(key)));
  }
}

/**
 * Generate offline response
 */
function getOfflineResponse() {
  return new Response(
    `<!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>ReelTalk - Offline</title>
      <style>
        body {
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
          display: flex;
          align-items: center;
          justify-content: center;
          min-height: 100vh;
          margin: 0;
          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
          color: white;
          text-align: center;
          padding: 20px;
        }
        .container {
          max-width: 400px;
        }
        h1 {
          font-size: 3rem;
          margin: 0 0 1rem 0;
        }
        p {
          font-size: 1.2rem;
          margin: 0 0 2rem 0;
          opacity: 0.9;
        }
        button {
          background: white;
          color: #667eea;
          border: none;
          padding: 12px 32px;
          font-size: 1rem;
          border-radius: 25px;
          cursor: pointer;
          font-weight: 600;
          transition: transform 0.2s;
        }
        button:hover {
          transform: scale(1.05);
        }
      </style>
    </head>
    <body>
      <div class="container">
        <h1>📡</h1>
        <h1>You're Offline</h1>
        <p>Please check your internet connection and try again.</p>
        <button onclick="location.reload()">Retry</button>
      </div>
    </body>
    </html>`,
    {
      headers: { 'Content-Type': 'text/html' }
    }
  );
}

// ============================================================================
// Background Sync (Optional - for future implementation)
// ============================================================================

self.addEventListener('sync', (event) => {
  if (event.tag === 'sync-messages') {
    event.waitUntil(syncMessages());
  }
});

async function syncMessages() {
  // Placeholder for future background sync implementation
  console.log('🔄 Background sync triggered');
}

// ============================================================================
// Push Notifications (Optional - for future implementation)
// ============================================================================

self.addEventListener('push', (event) => {
  const data = event.data ? event.data.json() : {};
  
  const options = {
    body: data.body || 'You have a new notification',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: data,
    vibrate: [200, 100, 200]
  };
  
  event.waitUntil(
    self.registration.showNotification(data.title || 'ReelTalk', options)
  );
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  
  event.waitUntil(
    clients.openWindow(event.notification.data.url || '/')
  );
});

// ============================================================================
// Message Handler (for SKIP_WAITING and other commands)
// ============================================================================

self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
});
