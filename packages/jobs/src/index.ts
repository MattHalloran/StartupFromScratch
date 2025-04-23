import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function runJobs() {
  console.log('Starting job worker');
  // TODO: implement job processing logic
  await prisma.$disconnect();
}

runJobs().catch((err) => {
  console.error(err);
}); 