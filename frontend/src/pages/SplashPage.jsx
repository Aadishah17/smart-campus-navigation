import { Link } from "react-router-dom";

function SplashPage() {
  return (
    <div className="splash-page">
      <div className="splash-overlay" />
      <section className="splash-content">
        <p className="eyebrow">Smart Campus Navigation System</p>
        <h1>Navigate Campus Faster with Live GPS and AI Guidance</h1>
        <p>
          Built for students, faculty, and visitors to find buildings, discover nearby
          facilities, and follow shortest routes inside campus.
        </p>
        <div className="splash-actions">
          <Link to="/dashboard" className="primary-button">
            Open Dashboard
          </Link>
          <Link to="/about" className="ghost-button">
            Project Scope
          </Link>
        </div>
      </section>
    </div>
  );
}

export default SplashPage;

