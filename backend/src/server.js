require("dotenv").config();

const app = require("./app");
const { connectDatabase } = require("./config/db");

const port = Number(process.env.PORT || 5050);

async function startServer() {
  await connectDatabase();

  app.listen(port, () => {
    console.log(`[server] Smart Campus backend running on port ${port}`);
  });
}

startServer().catch((error) => {
  console.error("[server] Failed to start:", error);
  process.exit(1);
});
