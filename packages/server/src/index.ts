import express from 'express';
import dotenv from 'dotenv';

// Load environment variables from .env-dev or .env-prod
dotenv.config();

const app = express();
const port = process.env.PORT || 4000;

// Basic health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

app.listen(port, () => {
  console.log(`Server running at http://localhost:${port}`);
}); 