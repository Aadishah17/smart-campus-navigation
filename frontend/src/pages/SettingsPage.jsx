import { useEffect, useState } from "react";
import TopNav from "../components/TopNav";
import { apiBaseUrl, fetchHealth } from "../api/campusApi";

function SettingsPage() {
  const [backendStatus, setBackendStatus] = useState("Checking...");
  const [healthTimestamp, setHealthTimestamp] = useState("");
  const [backendMode, setBackendMode] = useState("");

  useEffect(() => {
    async function checkHealth() {
      try {
        const health = await fetchHealth();
        setBackendStatus(health.status === "ok" ? "Online" : "Unexpected response");
        setHealthTimestamp(health.timestamp || "");
        setBackendMode(health.database?.mode || "");
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
          {backendMode ? <p>Database Mode: {backendMode}</p> : null}
        </section>

        <section className="content-card">
          <h2>Navigation Safeguards</h2>
          <p>
            The dashboard now validates backend coordinates against the uploaded Parul
            University campus dataset. If backend data or browser GPS drifts off campus,
            the app keeps the map centered on the validated campus focus instead of
            following a random location.
          </p>
        </section>

        <section className="content-card">
          <h2>Permissions</h2>
          <p>
            For live in-campus navigation and nearby suggestions, allow browser location
            access for this app. If permission is denied, the navigator falls back to the
            Parul campus anchor instead of leaving the map empty.
          </p>
        </section>
      </main>
    </div>
  );
}

export default SettingsPage;
