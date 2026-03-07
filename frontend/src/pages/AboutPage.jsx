import TopNav from "../components/TopNav";

function AboutPage() {
  return (
    <div className="page generic-page">
      <TopNav />
      <main className="content-wrap">
        <h1>About The Project</h1>
        <p>
          This version of the Smart Campus Navigation System is tuned specifically for
          Parul University and is designed to keep campus navigation usable even when
          browser GPS or backend data is unreliable.
        </p>

        <section className="content-card">
          <h2>Core Objectives</h2>
          <ul>
            <li>Keep the app pinned to Parul University instead of drifting to random map locations</li>
            <li>Validate campus coordinates against the uploaded project data before rendering them</li>
            <li>Provide nearby suggestions, route planning, and assistant help with local fallbacks</li>
            <li>Support smoother wayfinding for students, faculty, and visitors inside the campus</li>
            <li>Maintain a backend-ready architecture while still working when backend services degrade</li>
          </ul>
        </section>

        <section className="content-card">
          <h2>What Changed</h2>
          <p>
            The web client now verifies campus data against the uploaded Parul coordinate
            set, locks the map to a campus-safe focus when GPS is off-site, and falls back
            to a local navigation engine for nearby search, route planning, and assistant
            replies when backend responses are unavailable or mismatched.
          </p>
        </section>

        <section className="content-card">
          <h2>Architecture</h2>
          <p>
            Frontend is built with React and Leaflet. The backend uses Node.js and Express.
            Route planning uses a geographic campus graph generated from the mapped Parul
            locations, so routing remains functional even when the uploaded data does not
            include a pre-authored edge list.
          </p>
        </section>
      </main>
    </div>
  );
}

export default AboutPage;
