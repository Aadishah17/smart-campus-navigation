import { useEffect, useMemo, useState } from "react";
import {
  fetchLocations,
  fetchNearby,
  fetchRoute,
} from "../api/campusApi";
import useGeolocation from "../hooks/useGeolocation";
import TopNav from "../components/TopNav";
import CampusMap from "../components/CampusMap";
import AssistantWidget from "../components/AssistantWidget";

function DashboardPage() {
  const [locations, setLocations] = useState([]);
  const [selectedLocationId, setSelectedLocationId] = useState("");
  const [searchValue, setSearchValue] = useState("");
  const [sourceMode, setSourceMode] = useState("gps");
  const [sourceId, setSourceId] = useState("");
  const [destinationId, setDestinationId] = useState("");
  const [routeData, setRouteData] = useState(null);
  const [nearbyLocations, setNearbyLocations] = useState([]);
  const [loadingLocations, setLoadingLocations] = useState(true);
  const [loadingRoute, setLoadingRoute] = useState(false);
  const [error, setError] = useState("");
  const [followUser, setFollowUser] = useState(true);

  const { position, error: geolocationError, permissionDenied, loading } = useGeolocation();

  useEffect(() => {
    async function loadLocations() {
      try {
        setLoadingLocations(true);
        const payload = await fetchLocations();
        setLocations(payload);
        if (payload.length > 0) {
          setSelectedLocationId(payload[0].id);
          setDestinationId(payload[0].id);
          setSourceId(payload[0].id);
        }
      } catch {
        setError("Could not load campus locations. Start backend and refresh.");
      } finally {
        setLoadingLocations(false);
      }
    }

    loadLocations();
  }, []);

  useEffect(() => {
    async function loadNearby() {
      if (!position) {
        setNearbyLocations([]);
        return;
      }

      try {
        const payload = await fetchNearby(position.lat, position.lng);
        setNearbyLocations(payload);
      } catch {
        setNearbyLocations([]);
      }
    }

    loadNearby();
  }, [position]);

  const selectedLocation = useMemo(
    () => locations.find((location) => location.id === selectedLocationId) || null,
    [locations, selectedLocationId],
  );

  const filteredLocations = useMemo(() => {
    const lowerSearch = searchValue.toLowerCase();
    return locations.filter((location) => {
      return (
        location.name.toLowerCase().includes(lowerSearch) ||
        location.type.toLowerCase().includes(lowerSearch)
      );
    });
  }, [locations, searchValue]);

  async function handleRouteSubmit(event) {
    event.preventDefault();
    setError("");
    setRouteData(null);

    if (!destinationId) {
      setError("Select a destination first.");
      return;
    }

    const payload = { destinationId };

    if (sourceMode === "gps") {
      if (!position) {
        setError("GPS location not available. Switch to manual source.");
        return;
      }
      payload.sourcePosition = position;
    } else {
      if (!sourceId) {
        setError("Select source location.");
        return;
      }
      payload.sourceId = sourceId;
    }

    try {
      setLoadingRoute(true);
      const response = await fetchRoute(payload);
      setRouteData(response);
    } catch (apiError) {
      setError(apiError.response?.data?.message || "Route calculation failed.");
    } finally {
      setLoadingRoute(false);
    }
  }

  const noRouteFound = error.toLowerCase().includes("no route found");

  return (
    <div className="page dashboard-page">
      <TopNav />

      <main className="dashboard-main">
        <section className="hero-strip">
          <article>
            <h2>{locations.length}</h2>
            <p>Mapped Campus Locations</p>
          </article>
          <article>
            <h2>{nearbyLocations.length}</h2>
            <p>Nearby to You</p>
          </article>
          <article>
            <h2>{routeData ? `${routeData.totalDistanceKm} km` : "--"}</h2>
            <p>Route Distance</p>
          </article>
          <article>
            <h2>{routeData ? `${routeData.estimatedWalkMinutes} min` : "--"}</h2>
            <p>Estimated Walk</p>
          </article>
        </section>

        {permissionDenied ? (
          <section className="alert-card">
            <h3>Location Permission Error Screen</h3>
            <p>
              GPS access is disabled. Enable location permission in browser settings
              for real-time user tracking.
            </p>
          </section>
        ) : null}

        {error ? (
          <section className={noRouteFound ? "alert-card warning" : "alert-card"}>
            <h3>{noRouteFound ? "No Route Found Screen" : "Navigation Message"}</h3>
            <p>{error}</p>
          </section>
        ) : null}

        <section className="dashboard-grid">
          <article className="panel panel-map">
            <div className="panel-head">
              <h3>Map Screen</h3>
              <label>
                <input
                  type="checkbox"
                  checked={followUser}
                  onChange={(event) => setFollowUser(event.target.checked)}
                />
                Follow GPS
              </label>
            </div>
            <CampusMap
              locations={locations}
              userPosition={position}
              routePath={routeData?.path || []}
              selectedLocationId={selectedLocationId}
              onSelectLocation={setSelectedLocationId}
              followUser={followUser}
            />
          </article>

          <article className="panel">
            <div className="panel-head">
              <h3>Location Selection + Route Display</h3>
            </div>
            <form className="route-form" onSubmit={handleRouteSubmit}>
              <label>
                Source Mode
                <select
                  value={sourceMode}
                  onChange={(event) => setSourceMode(event.target.value)}
                >
                  <option value="gps">Current GPS Location</option>
                  <option value="manual">Manual Location</option>
                </select>
              </label>

              {sourceMode === "manual" ? (
                <label>
                  Source Location
                  <select
                    value={sourceId}
                    onChange={(event) => setSourceId(event.target.value)}
                  >
                    {locations.map((location) => (
                      <option key={location.id} value={location.id}>
                        {location.name}
                      </option>
                    ))}
                  </select>
                </label>
              ) : null}

              <label>
                Destination
                <select
                  value={destinationId}
                  onChange={(event) => setDestinationId(event.target.value)}
                >
                  {locations.map((location) => (
                    <option key={location.id} value={location.id}>
                      {location.name}
                    </option>
                  ))}
                </select>
              </label>

              <button type="submit" className="primary-button" disabled={loadingRoute}>
                {loadingRoute ? "Calculating..." : "Find Shortest Path"}
              </button>
            </form>

            {routeData ? (
              <div className="route-result">
                <h4>Route Summary</h4>
                <p>
                  Source: <strong>{routeData.source?.name}</strong>
                </p>
                <p>
                  Destination: <strong>{routeData.destination?.name}</strong>
                </p>
                <p>
                  Total Distance: <strong>{routeData.totalDistanceKm} km</strong>
                </p>
                <p>
                  Estimated Walk Time:{" "}
                  <strong>{routeData.estimatedWalkMinutes} minutes</strong>
                </p>
                <ol>
                  {routeData.path.map((stop) => (
                    <li key={stop.id}>{stop.name}</li>
                  ))}
                </ol>
              </div>
            ) : (
              <p className="subtle">Run a route search to see step-by-step path.</p>
            )}
          </article>

          <article className="panel">
            <div className="panel-head">
              <h3>Search Location Screen</h3>
            </div>
            <input
              className="search-input"
              placeholder="Search building or facility"
              value={searchValue}
              onChange={(event) => setSearchValue(event.target.value)}
            />

            <div className="location-list">
              {loadingLocations || loading ? (
                <p className="subtle">Loading location data...</p>
              ) : filteredLocations.length ? (
                filteredLocations.map((location) => (
                  <button
                    key={location.id}
                    type="button"
                    className={
                      selectedLocationId === location.id
                        ? "location-item active"
                        : "location-item"
                    }
                    onClick={() => setSelectedLocationId(location.id)}
                  >
                    <span>{location.name}</span>
                    <small>{location.type}</small>
                  </button>
                ))
              ) : (
                <p className="subtle">No locations match your search.</p>
              )}
            </div>
          </article>

          <article className="panel">
            <div className="panel-head">
              <h3>Location Details + Nearby Info</h3>
            </div>

            {selectedLocation ? (
              <div className="details-block">
                <h4>{selectedLocation.name}</h4>
                <p>{selectedLocation.description}</p>
                <p>
                  Coordinates: {selectedLocation.lat.toFixed(5)},{" "}
                  {selectedLocation.lng.toFixed(5)}
                </p>
                <h5>Facilities</h5>
                <ul>
                  {selectedLocation.facilities.map((facility) => (
                    <li key={facility}>{facility}</li>
                  ))}
                </ul>
              </div>
            ) : (
              <p className="subtle">Select a marker or location for details.</p>
            )}

            <div className="nearby-block">
              <h5>Nearby from Current Position</h5>
              {nearbyLocations.length ? (
                <ul>
                  {nearbyLocations.map((location) => (
                    <li key={location.id}>
                      {location.name} ({Math.round(location.distanceMeters)} m)
                    </li>
                  ))}
                </ul>
              ) : (
                <p className="subtle">{geolocationError || "Enable GPS to see nearby data."}</p>
              )}
            </div>
          </article>
        </section>
      </main>

      <AssistantWidget userPosition={position} />
    </div>
  );
}

export default DashboardPage;
