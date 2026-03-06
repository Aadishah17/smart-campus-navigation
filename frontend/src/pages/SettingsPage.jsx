import { useEffect, useState } from "react";
import TopNav from "../components/TopNav";
import { apiBaseUrl, fetchHealth } from "../api/campusApi";

function SettingsPage() {
  const [backendStatus, setBackendStatus] = useState("Checking...");
  const [healthTimestamp, setHealthTimestamp] = useState("");

  useEffect(() => {
    async function checkHealth() {
      try {
        const health = await fetchHealth();
        setBackendStatus(health.status === "ok" ? "Online" : "Unexpected response");
        setHealthTimestamp(health.timestamp || "");
      } catch {
        setBackendStatus("Offline");
      }
    }

    checkHealth();
  }, []);

  return (
    <div className="page generic-page">
      <TopNav />
      <main className="content-wrap">
        <h1>Settings</h1>

        <section className="content-card">
          <h2>Integration</h2>
          <p>
            API Base URL: <code>{apiBaseUrl}</code>
          </p>
          <p>Backend Status: {backendStatus}</p>
          {healthTimestamp ? <p>Last Health Check: {healthTimestamp}</p> : null}
        </section>

        <section className="content-card">
          <h2>Permissions</h2>
          <p>
            For live navigation and nearby suggestions, allow browser location access
            for this app.
          </p>
        </section>
      </main>
    </div>
  );
}

export default SettingsPage;
