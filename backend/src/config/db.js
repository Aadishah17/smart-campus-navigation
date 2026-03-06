const mongoose = require("mongoose");

let lastConnectionError = null;
let mongoConfigured = false;

async function connectDatabase() {
  const mongoUri = process.env.MONGO_URI;
  mongoConfigured = Boolean(mongoUri && String(mongoUri).trim());

  if (!mongoConfigured) {
    console.log("[db] MONGO_URI not set. Using in-memory seed data.");
    lastConnectionError = "MONGO_URI not configured.";
    return false;
  }

  try {
    await mongoose.connect(mongoUri, {
      serverSelectionTimeoutMS: 5000,
    });
    lastConnectionError = null;
    console.log("[db] Connected to MongoDB.");
    return true;
  } catch (error) {
    lastConnectionError = error.message;
    console.warn(
      `[db] Could not connect to MongoDB (${error.message}). Falling back to in-memory seed data.`,
    );
    return false;
  }
}

function isDatabaseConnected() {
  return mongoose.connection.readyState === 1;
}

function getDatabaseStatus() {
  const connected = isDatabaseConnected();
  return {
    connected,
    mode: connected ? "mongodb" : "seed",
    mongoConfigured,
    readyState: mongoose.connection.readyState,
    lastError: lastConnectionError,
  };
}

module.exports = { connectDatabase, getDatabaseStatus, isDatabaseConnected };
