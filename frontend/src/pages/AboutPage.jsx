import TopNav from "../components/TopNav";

function AboutPage() {
  return (
    <div className="page generic-page">
      <TopNav />
      <main className="content-wrap">
        <h1>About The Project</h1>
        <p>
          This Smart Campus Navigation System is a web-based navigation platform built
          to help students, faculty, and visitors move inside a campus quickly.
        </p>

        <section className="content-card">
          <h2>Core Objectives</h2>
          <ul>
            <li>Interactive campus map with building markers</li>
            <li>GPS-based real-time user location tracking</li>
            <li>Dijkstra shortest-path route calculation</li>
            <li>AI assistant for contextual building information</li>
            <li>Scalable backend with MongoDB-ready data model</li>
          </ul>
        </section>

        <section className="content-card">
          <h2>Architecture</h2>
          <p>
            Frontend in React + Leaflet, backend in Node.js + Express, and optional
            MongoDB persistence. Campus graph data is used for route optimization.
          </p>
        </section>
      </main>
    </div>
  );
}

export default AboutPage;

