import { Link, useLocation } from "react-router-dom";

const links = [
  { path: "/dashboard", label: "Navigator" },
  { path: "/about", label: "Project" },
  { path: "/settings", label: "Settings" },
];

function TopNav() {
  const location = useLocation();

  return (
    <header className="top-nav">
      <Link to="/dashboard" className="brand">
        Parul University Navigator
      </Link>
      <nav>
        {links.map((link) => (
          <Link
            key={link.path}
            to={link.path}
            className={location.pathname === link.path ? "nav-link active" : "nav-link"}
          >
            {link.label}
          </Link>
        ))}
      </nav>
    </header>
  );
}

export default TopNav;
