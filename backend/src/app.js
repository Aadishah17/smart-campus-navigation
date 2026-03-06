const express = require("express");
const cors = require("cors");
const morgan = require("morgan");
const { getDatabaseStatus } = require("./config/db");
const locationRoutes = require("./routes/locationRoutes");
const navigationRoutes = require("./routes/navigationRoutes");
const assistantRoutes = require("./routes/assistantRoutes");

const app = express();

const corsOrigin = process.env.CORS_ORIGIN;
const corsConfig = corsOrigin
  ? {
      origin: corsOrigin.split(",").map((origin) => origin.trim()),
    }
  : {};

app.use(cors(corsConfig));
app.use(morgan("dev"));
app.use(express.json());

app.get("/api/health", (req, res) => {
  res.json({
    status: "ok",
    database: getDatabaseStatus(),
    timestamp: new Date().toISOString(),
  });
});

app.use("/api/locations", locationRoutes);
app.use("/api/navigation", navigationRoutes);
app.use("/api/assistant", assistantRoutes);

app.use((req, res) => {
  res.status(404).json({ message: "Route not found." });
});

app.use((error, req, res, next) => {
  console.error("[error]", error);
  res.status(500).json({
    message: "Internal server error.",
    details:
      process.env.NODE_ENV === "development"
        ? error.message
        : "Enable development mode to see details.",
  });
});

module.exports = app;
