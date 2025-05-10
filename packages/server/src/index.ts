import cookie from "cookie";
import cors from "cors";
import express from "express";
import path from "path";
import { fileURLToPath } from "url";
import { SERVER_PORT, SERVER_URL, server } from "./server.js";
import { logger } from "./events/logger.js";
import { app } from "./app.js";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function main() {
    logger.info("Starting server...");

    // Check for required .env variables
    const requiredEnvs = [
        "JWT_PRIV", // Private key for JWT tokens
        "JWT_PUB", // Public key for JWT tokens
        "PROJECT_DIR", // Path to the project directory
        "VITE_SERVER_LOCATION", // Location of the server
        "VAPID_PUBLIC_KEY", // Public key for VAPID
        "VAPID_PRIVATE_KEY", // Private key for VAPID
        "WORKER_ID", // Worker ID (e.g. pod ordinal) for Snowflake IDs
    ];
    for (const env of requiredEnvs) {
        if (!process.env[env]) {
            logger.error(`🚨 ${env} not in environment variables. Stopping server`, { trace: "0007" });
            process.exit(1);
        }
    }

    // Unhandled Rejection Handler. This is a last resort for catching errors that were not caught by the application. 
    // If you see this error, please try to find its source and catch it there.
    process.on("unhandledRejection", (reason, promise) => {
        logger.error("🚨 Unhandled Rejection", { trace: "0003", reason, promise });
    });

    // Add health check endpoint
    app.get("/healthcheck", (req, res) => {
        res.status(200).send("OK");
    });

    // Start Express server
    server.listen(SERVER_PORT);
    logger.info(`🚀 Server running at ${SERVER_URL}`);
}

// Only call this from the "server" package when not testing
if (
    process.env.npm_package_name?.endsWith('/server') &&
    process.env.NODE_ENV !== "test"
) {
    main();
}
