import { Link } from "react-router-dom";

function SplashPage() {
  return (
    <div className="splash-page">
      <div className="splash-overlay" />
      <section className="splash-content">
        <p className="eyebrow">Parul University Smart Navigation</p>
        <h1>Find buildings, hostels, food courts, and smooth campus routes without drifting off-site.</h1>
        <p>
          Built around validated Parul University coordinates with live GPS tracking,
          map-safe campus fallback, nearby discovery, and route guidance for students,
          staff, and visitors.
        </p>
        <div className="splash-actions">
          <Link to="/dashboard" className="primary-button">
            Open Navigator
          </Link>
          <Link to="/about" className="ghost-button">
            View Project Scope
          </Link>
        </div>
      </section>
    </div>
  );
}

export default SplashPage;
