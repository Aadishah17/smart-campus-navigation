import axios from "axios";

const apiBaseUrl = import.meta.env.VITE_API_BASE_URL || "http://localhost:5050/api";

const apiClient = axios.create({
  baseURL: apiBaseUrl,
  timeout: 12000,
});

export async function fetchLocations() {
  const response = await apiClient.get("/locations");
  return response.data.data || [];
}

export async function fetchRoute(payload) {
  const response = await apiClient.post("/navigation/route", payload);
  return response.data;
}

export async function fetchNearby(lat, lng, radius = 900, limit = 6) {
  const response = await apiClient.get("/navigation/nearby", {
    params: { lat, lng, radius, limit },
  });
  return response.data.data || [];
}

export async function askAssistant(message, userPosition) {
  const response = await apiClient.post("/assistant/chat", {
    message,
    userPosition,
  });
  return response.data;
}

export async function fetchHealth() {
  const response = await apiClient.get("/health");
  return response.data;
}

export { apiBaseUrl };
