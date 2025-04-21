import { createClient } from 'redis';

// Initialize Redis client
const redisUrl = process.env.REDIS_URL;
if (!redisUrl) {
  throw new Error('REDIS_URL is not defined');
}

const client = createClient({ url: redisUrl });
client.on('error', (err) => console.error('Redis Client Error', err));
await client.connect();

export default client; 