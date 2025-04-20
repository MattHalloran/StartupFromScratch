import dotenv from 'dotenv';
import { PrismaClient } from '@prisma/client';
import redisClient from '@startupfromscratch/redis-db';

// Load env variables
dotenv.config();

const prisma = new PrismaClient();

async function runJobs() {
  console.log('Starting job worker');
  // TODO: implement job processing logic
  await prisma.$disconnect();
  await redisClient.disconnect();
}

runJobs().catch((err) => {
  console.error(err);
  process.exit(1);
}); 