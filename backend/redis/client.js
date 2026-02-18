import { Redis } from "ioredis";

let client;
let redisAvailable = false;

// Mock implementation
class MockRedis {
    constructor() {
        this.store = new Map();
        console.log("Initialized In-Memory Redis Mock");
    }

    async get(key) {
        const item = this.store.get(key);
        if (!item) return null;
        if (item.expiry && Date.now() > item.expiry) {
            this.store.delete(key);
            return null;
        }
        return item.value;
    }

    async set(key, value) {
        this.store.set(key, { value, expiry: null });
        return "OK";
    }

    async expire(key, seconds) {
        const item = this.store.get(key);
        if (item) {
            item.expiry = Date.now() + seconds * 1000;
            this.store.set(key, item);
        }
        return 1;
    }

    async del(key) {
        this.store.delete(key);
        return 1;
    }
}

const mockClient = new MockRedis();

try {
    client = new Redis({
        retryStrategy: (times) => {
            if (times > 3) {
                return null; // Stop retrying after 3 attempts
            }
            return Math.min(times * 50, 2000);
        },
        maxRetriesPerRequest: 1
    });

    client.on("connect", () => {
        console.log("Connected to Redis");
        redisAvailable = true;
    });

    client.on("error", (err) => {
        if (redisAvailable) {
            console.log("Redis connection error:", err.message);
            redisAvailable = false;
        }
    });

} catch (error) {
    console.log("Failed to initialize Redis client, using mock.");
}

// Export a proxy that delegates to the appropriate client
const proxyClient = new Proxy({}, {
    get: (target, prop) => {
        if (redisAvailable && client) {
            return client[prop];
        }
        // Fallback to mock for standard methods
        if (mockClient[prop]) {
            return mockClient[prop];
        }
        // Return no-op for event listeners to prevent crashes
        if (prop === 'on') return () => { };

        return undefined;
    }
});

export { proxyClient as client };