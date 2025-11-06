// Worker Manager - Manages Web Workers for performance optimization
// This provides a simple API for Flutter to interact with web workers

class WorkerManager {
  constructor() {
    this.worker = null;
    this.messageHandlers = new Map();
    this.isReady = false;
    this.initWorker();
  }

  initWorker() {
    try {
      // Check if Web Workers are supported
      if (typeof(Worker) === "undefined") {
        console.warn('⚠️ Web Workers not supported in this browser');
        return;
      }

      // Create the worker
      this.worker = new Worker('app_worker.js');
      
      // Set up message handler
      this.worker.addEventListener('message', (e) => {
        this.handleMessage(e.data);
      });

      // Set up error handler
      this.worker.addEventListener('error', (e) => {
      console.error('❌ Worker error:', e.message, e);
    });

    } catch (error) {
      console.error('❌ Failed to initialize worker:', error);
    }
  }  handleMessage(message) {
    const { type, ...data } = message;

    if (type === 'READY') {
      this.isReady = true;
      return;
    }

    // Call registered handlers
    const handlers = this.messageHandlers.get(type) || [];
    handlers.forEach(handler => {
      try {
        handler(data);
      } catch (error) {
        console.error('❌ Error in message handler:', error);
      }
    });
  }

  // Send message to worker
  postMessage(type, data) {
    if (!this.worker) {
      console.warn('⚠️ Worker not available');
      return Promise.reject(new Error('Worker not available'));
    }

    return new Promise((resolve, reject) => {
      // Register one-time handler for response
      const responseType = type + '_COMPLETE';
      this.on(responseType, (result) => {
        this.off(responseType);
        resolve(result);
      });

      // Register error handler
      this.on('ERROR', (error) => {
        this.off('ERROR');
        reject(error);
      });

      // Send message
      this.worker.postMessage({ type, data });
    });
  }

  // Register event handler
  on(type, handler) {
    if (!this.messageHandlers.has(type)) {
      this.messageHandlers.set(type, []);
    }
    this.messageHandlers.get(type).push(handler);
  }

  // Unregister event handler
  off(type, handler) {
    if (!this.messageHandlers.has(type)) return;
    
    if (handler) {
      const handlers = this.messageHandlers.get(type);
      const index = handlers.indexOf(handler);
      if (index > -1) {
        handlers.splice(index, 1);
      }
    } else {
      // Remove all handlers for this type
      this.messageHandlers.delete(type);
    }
  }

  // Preload images in background
  preloadImages(urls) {
    return this.postMessage('PRELOAD_IMAGES', urls);
  }

  // Process data in background
  processData(data) {
    return this.postMessage('PROCESS_DATA', data);
  }

  // Parse JSON in background
  parseJson(jsonString) {
    return this.postMessage('PARSE_JSON', jsonString);
  }

  // Terminate worker
  terminate() {
    if (this.worker) {
      this.worker.terminate();
      this.worker = null;
      this.isReady = false;
      console.log('✅ Worker terminated');
    }
  }
}

// Create global instance
window.workerManager = new WorkerManager();

// Expose API to Flutter
window.useWebWorker = function(type, data) {
  return window.workerManager.postMessage(type, data);
};
