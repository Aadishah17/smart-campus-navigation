import { BrowserRouter, Navigate, Route, Routes } from "react-router-dom";
import SplashPage from "./pages/SplashPage";
import DashboardPage from "./pages/DashboardPage";
import AboutPage from "./pages/AboutPage";
import SettingsPage from "./pages/SettingsPage";

function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<SplashPage />} />
        <Route path="/dashboard" element={<DashboardPage />} />
        <Route path="/about" element={<AboutPage />} />
        <Route path="/settings" element={<SettingsPage />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  );
}

export default App;

