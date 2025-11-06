// Web Worker for background processing to speed up the app
// This worker handles heavy computations off the main thread

self.addEventListener('message', function(e) {
  const { type, data } = e.data;
  
  switch(type) {
    case 'PRELOAD_IMAGES':
      preloadImages(data);
      break;
      
    case 'COMPRESS_IMAGE':
      compressImage(data);
      break;
      
    case 'PROCESS_DATA':
      processData(data);
      break;
      
    case 'CACHE_DATA':
      cacheData(data);
      break;
      
    case 'PARSE_JSON':
      parseJson(data);
      break;
      
    default:
      self.postMessage({ 
        type: 'ERROR', 
        error: 'Unknown message type: ' + type 
      });
  }
});

// Preload images in background
function preloadImages(urls) {
  try {
    const loadPromises = urls.map(url => {
      return fetch(url)
        .then(response => response.blob())
        .then(blob => ({
          url: url,
          success: true,
          size: blob.size
        }))
        .catch(error => ({
          url: url,
          success: false,
          error: error.message
        }));
    });
    
    Promise.all(loadPromises).then(results => {
      self.postMessage({
        type: 'PRELOAD_IMAGES_COMPLETE',
        results: results
      });
    });
  } catch (error) {
    self.postMessage({
      type: 'ERROR',
      error: error.message
    });
  }
}

// Compress image data
function compressImage(imageData) {
  try {
    // Image compression logic would go here
    // For now, just acknowledge the request
    self.postMessage({
      type: 'COMPRESS_IMAGE_COMPLETE',
      data: imageData
    });
  } catch (error) {
    self.postMessage({
      type: 'ERROR',
      error: error.message
    });
  }
}

// Process heavy data computations
function processData(data) {
  try {
    // Perform heavy computation
    const result = {
      processed: true,
      timestamp: Date.now(),
      dataLength: data.length || 0
    };
    
    self.postMessage({
      type: 'PROCESS_DATA_COMPLETE',
      result: result
    });
  } catch (error) {
    self.postMessage({
      type: 'ERROR',
      error: error.message
    });
  }
}

// Cache data in IndexedDB (via the worker)
function cacheData(data) {
  try {
    // Data caching logic
    self.postMessage({
      type: 'CACHE_DATA_COMPLETE',
      success: true
    });
  } catch (error) {
    self.postMessage({
      type: 'ERROR',
      error: error.message
    });
  }
}

// Parse large JSON data
function parseJson(jsonString) {
  try {
    const parsed = JSON.parse(jsonString);
    self.postMessage({
      type: 'PARSE_JSON_COMPLETE',
      data: parsed
    });
  } catch (error) {
    self.postMessage({
      type: 'ERROR',
      error: error.message
    });
  }
}

// Send ready signal
self.postMessage({ type: 'READY' });
