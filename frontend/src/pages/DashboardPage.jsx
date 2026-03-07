import { useDeferredValue, useEffect, useMemo, useState } from "react";
import { fetchLocations, fetchNearby, fetchRoute } from "../api/campusApi";
import useGeolocation from "../hooks/useGeolocation";
import TopNav from "../components/TopNav";
import CampusMap from "../components/CampusMap";
import AssistantWidget from "../components/AssistantWidget";
import parulCampusLocations from "../data/parulCampusLocations";
import {
  buildNetworkEdges,
  buildRouteLegs,
  calculateRoute,
  campusAnchor,
  campusCenter,
  findNearbyLocations,
  findNearestLocation,
  formatDistance,
  isLikelyParulDataset,
  isOnCampus,
  normalizeLocations,
} from "../services/campusEngine";

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
  const [dataMode, setDataMode] = useState("loading");
  const [dataNote, setDataNote] = useState("");

  const deferredSearchValue = useDeferredValue(searchValue);
  const {
    position,
    error: geolocationError,
    permissionDenied,
    loading: loadingLocation,
  } = useGeolocation();

  useEffect(() => {
    async function loadLocations() {
      setLoadingLocations(true);
      setError("");

      try {
        const payload = normalizeLocations(await fetchLocations());
        if (payload.length && isLikelyParulDataset(payload)) {
          setLocations(payload);
          setDataMode("backend");
          setDataNote("Validated live backend data matched the uploaded Parul campus coordinates.");
          return;
        }

        setLocations(parulCampusLocations);
        setDataMode("validated-fallback");
        setDataNote(
          payload.length
            ? "Backend location data did not match the uploaded Parul University coordinates, so the app switched to the validated campus dataset."
            : "Backend returned no usable campus points, so the validated Parul dataset is active.",
        );
      } catch {
        setLocations(parulCampusLocations);
        setDataMode("validated-fallback");
        setDataNote(
          "Backend is unavailable, so the dashboard is using the validated Parul University campus dataset locally.",
        );
      } finally {
        setLoadingLocations(false);
      }
    }

    loadLocations();
  }, []);

  const anchorLocation = useMemo(() => campusAnchor(locations), [locations]);
  const defaultDestination = useMemo(
    () =>
      locations.find((location) => location.id === "administrative-block") ||
      locations.find((location) => location.id === "main-food-court") ||
      anchorLocation,
    [anchorLocation, locations],
  );

  useEffect(() => {
    if (!locations.length || !anchorLocation) {
      return;
    }

    if (!selectedLocationId || !locations.some((location) => location.id === selectedLocationId)) {
      setSelectedLocationId(anchorLocation.id);
    }
    if (!sourceId || !locations.some((location) => location.id === sourceId)) {
      setSourceId(anchorLocation.id);
    }
    if (!destinationId || !locations.some((location) => location.id === destinationId)) {
      setDestinationId(defaultDestination?.id || anchorLocation.id);
    }
  }, [anchorLocation, defaultDestination, destinationId, locations, selectedLocationId, sourceId]);

  const userOnCampus = useMemo(
    () => isOnCampus(locations, position),
    [locations, position],
  );

  const campusPosition = useMemo(() => {
    if (position && userOnCampus) {
      return position;
    }

    return anchorLocation ? { lat: anchorLocation.lat, lng: anchorLocation.lng } : null;
  }, [anchorLocation, position, userOnCampus]);

  const selectedLocation = useMemo(
    () => locations.find((location) => location.id === selectedLocationId) || null,
    [locations, selectedLocationId],
  );

  const nearestCampusLocation = useMemo(
    () => (campusPosition ? findNearestLocation(locations, campusPosition) : null),
    [campusPosition, locations],
  );

  const networkEdges = useMemo(() => buildNetworkEdges(locations), [locations]);
  const routeLegs = useMemo(() => buildRouteLegs(routeData?.path || []), [routeData]);

  const filteredLocations = useMemo(() => {
    const normalizedSearch = deferredSearchValue.trim().toLowerCase();

    if (!normalizedSearch) {
      return locations;
    }

    return locations.filter((location) => {
      const searchable = [
        location.name,
        location.type,
        location.description,
        ...location.aliases,
        ...location.facilities,
      ]
        .join(" ")
        .toLowerCase();

      return searchable.includes(normalizedSearch);
    });
  }, [deferredSearchValue, locations]);

  const campusStats = useMemo(() => {
    const center = campusCenter(locations);

    return [
      {
        label: "Mapped Places",
        value: String(locations.length || parulCampusLocations.length),
      },
      {
        label: "Data Source",
        value: dataMode === "backend" ? "Live backend" : "Validated fallback",
      },
      {
        label: "Nearest Focus",
        value: nearestCampusLocation?.location?.name || "PU Circle",
      },
      {
        label: "Campus Center",
        value: `${center.lat.toFixed(4)}, ${center.lng.toFixed(4)}`,
      },
    ];
  }, [dataMode, locations, nearestCampusLocation]);

  const quickDestinations = useMemo(() => {
    if (!campusPosition) {
      return [];
    }

    const pick = (predicate, fallbackId) => {
      const nearby = findNearbyLocations(locations, {
        lat: campusPosition.lat,
        lng: campusPosition.lng,
        radiusMeters: 2500,
        limit: 1,
        predicate,
      });
      return nearby[0] || locations.find((location) => location.id === fallbackId) || null;
    };

    return [
      { label: "Food", location: pick((location) => location.type === "dining", "main-food-court") },
      { label: "Library", location: pick((location) => location.type === "library", "dr-r-c-shah-medical-library") },
      { label: "Admin", location: pick((location) => location.type === "admin", "administrative-block") },
      {
        label: "Hostel",
        location: pick((location) => location.type === "residential", "marie-curie-residence"),
      },
    ].filter((entry) => entry.location);
  }, [campusPosition, locations]);

  useEffect(() => {
    async function loadNearby() {
      if (!campusPosition || !locations.length) {
        setNearbyLocations([]);
        return;
      }

      const fallbackNearby = () =>
        findNearbyLocations(locations, {
          lat: campusPosition.lat,
          lng: campusPosition.lng,
          radiusMeters: 1000,
          limit: 6,
        });

      if (dataMode !== "backend") {
        setNearbyLocations(fallbackNearby());
        return;
      }

      try {
        const payload = normalizeLocations(
          await fetchNearby(campusPosition.lat, campusPosition.lng, 1000, 6),
        ).map((location) => ({
          ...location,
          distanceMeters:
            findNearestLocation(
              [location],
              { lat: campusPosition.lat, lng: campusPosition.lng },
            )?.distanceMeters || null,
        }));

        setNearbyLocations(payload.length ? payload : fallbackNearby());
      } catch {
        setNearbyLocations(fallbackNearby());
      }
    }

    loadNearby();
  }, [campusPosition, dataMode, locations]);

  async function handleRouteSubmit(event) {
    event.preventDefault();
    setError("");
    setRouteData(null);

    if (!destinationId) {
      setError("Select a destination first.");
      return;
    }

    const safeSourcePosition = sourceMode === "gps" ? campusPosition : null;
    const payload =
      sourceMode === "gps"
        ? { destinationId, sourcePosition: safeSourcePosition }
        : { destinationId, sourceId };

    const localFallback = () =>
      calculateRoute({
        locations,
        destinationId,
        sourceId: sourceMode === "manual" ? sourceId : null,
        sourcePosition: sourceMode === "gps" ? safeSourcePosition : null,
      });

    try {
      setLoadingRoute(true);

      if (dataMode === "backend") {
        const response = await fetchRoute(payload);
        if (response?.path?.length) {
          setRouteData(response);
          return;
        }
      }

      const fallbackRoute = localFallback();
      if (!fallbackRoute) {
        setError("No route found between the selected campus points.");
        return;
      }

      setRouteData(fallbackRoute);
    } catch {
      const fallbackRoute = localFallback();
      if (!fallbackRoute) {
        setError("Route calculation failed.");
        return;
      }

      setRouteData(fallbackRoute);
    } finally {
      setLoadingRoute(false);
    }
  }

  const focusMessage = userOnCampus
    ? "Following live GPS inside the mapped Parul University campus."
    : position
      ? `Your GPS appears outside the mapped campus, so navigation is pinned to ${anchorLocation?.name || "PU Circle"}.`
      : permissionDenied
        ? `Location permission is off, so the map is centered on ${anchorLocation?.name || "PU Circle"}.`
        : `Waiting for location access. The dashboard is centered on ${anchorLocation?.name || "PU Circle"} in the meantime.`;

  const routeSourceLabel =
    sourceMode === "gps"
      ? userOnCampus
        ? "Live campus GPS"
        : anchorLocation?.name || "PU Circle"
      : locations.find((location) => location.id === sourceId)?.name || "--";

  const noRouteFound = error.toLowerCase().includes("no route");

  return (
    <div className="page dashboard-page">
      <TopNav />

      <main className="dashboard-main">
        <section className="hero-panel">
          <div className="hero-copy">
            <p className="eyebrow">Parul University Navigator</p>
            <h1>Validated campus wayfinding with safer GPS focus and faster route planning.</h1>
            <p>
              The dashboard now verifies campus coordinates before using them, stays pinned
              to Parul University when the browser reports a bad location, and keeps route
              guidance usable even when the backend is unavailable.
            </p>
          </div>

          <div className="hero-actions">
            <button type="button" className="primary-button" onClick={() => setFollowUser(true)}>
              Follow Campus Focus
            </button>
            <button
              type="button"
              className="ghost-button"
              onClick={() => {
                if (anchorLocation) {
                  setSelectedLocationId(anchorLocation.id);
                  setDestinationId(anchorLocation.id);
                }
              }}
            >
              Jump to PU Circle
            </button>
            {quickDestinations.map((item) => (
              <button
                key={item.label}
                type="button"
                className="hero-chip"
                onClick={() => {
                  setSelectedLocationId(item.location.id);
                  setDestinationId(item.location.id);
                }}
              >
                {item.label}: {item.location.name}
              </button>
            ))}
          </div>

          <div className="hero-strip">
            {campusStats.map((item) => (
              <article key={item.label}>
                <h2>{item.value}</h2>
                <p>{item.label}</p>
              </article>
            ))}
          </div>
        </section>

        {permissionDenied ? (
          <section className="alert-card warning">
            <h3>Location access is disabled</h3>
            <p>
              Browser GPS permission is off, so live navigation is locked to the validated
              Parul campus anchor until you allow location access.
            </p>
          </section>
        ) : null}

        {error ? (
          <section className={noRouteFound ? "alert-card warning" : "alert-card"}>
            <h3>{noRouteFound ? "No campus route found" : "Navigation message"}</h3>
            <p>{error}</p>
          </section>
        ) : null}

        <section className="dashboard-layout">
          <div className="dashboard-column dashboard-column-main">
            <article className="panel panel-map">
              <div className="panel-head">
                <div>
                  <h3>Campus map</h3>
                  <p>{focusMessage}</p>
                </div>

                <label className="toggle-row">
                  <input
                    type="checkbox"
                    checked={followUser}
                    onChange={(event) => setFollowUser(event.target.checked)}
                  />
                  <span>Follow campus focus</span>
                </label>
              </div>

              <CampusMap
                locations={locations}
                campusPosition={campusPosition}
                routePath={routeData?.path || []}
                networkEdges={networkEdges}
                selectedLocationId={selectedLocationId}
                onSelectLocation={setSelectedLocationId}
                followUser={followUser}
                focusLabel={userOnCampus ? "Live campus focus active" : "Pinned to validated campus"}
                highlightLabel={selectedLocation?.name || ""}
                statusMessage={dataNote}
                userOnCampus={userOnCampus}
              />
            </article>

            <article className="panel">
              <div className="panel-head">
                <div>
                  <h3>Route planner</h3>
                  <p>Calculate a walking path between validated Parul campus locations.</p>
                </div>
              </div>

              <form className="route-form-grid" onSubmit={handleRouteSubmit}>
                <label>
                  Source mode
                  <select
                    value={sourceMode}
                    onChange={(event) => setSourceMode(event.target.value)}
                  >
                    <option value="gps">Campus focus position</option>
                    <option value="manual">Manual source</option>
                  </select>
                </label>

                {sourceMode === "manual" ? (
                  <label>
                    Source location
                    <select value={sourceId} onChange={(event) => setSourceId(event.target.value)}>
                      {locations.map((location) => (
                        <option key={location.id} value={location.id}>
                          {location.name}
                        </option>
                      ))}
                    </select>
                  </label>
                ) : (
                  <div className="planner-summary-card">
                    <span>Source</span>
                    <strong>{routeSourceLabel}</strong>
                    <small>{userOnCampus ? "Using live in-campus GPS" : "Using validated campus anchor"}</small>
                  </div>
                )}

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
                  {loadingRoute ? "Calculating route..." : "Find smoothest campus route"}
                </button>
              </form>

              {routeData ? (
                <div className="route-result">
                  <div className="route-summary-grid">
                    <div>
                      <span>Source</span>
                      <strong>{routeData.source?.name}</strong>
                    </div>
                    <div>
                      <span>Destination</span>
                      <strong>{routeData.destination?.name}</strong>
                    </div>
                    <div>
                      <span>Distance</span>
                      <strong>{routeData.totalDistanceKm} km</strong>
                    </div>
                    <div>
                      <span>Walk time</span>
                      <strong>{routeData.estimatedWalkMinutes} min</strong>
                    </div>
                  </div>

                  <div className="route-path-list">
                    {routeData.path.map((stop) => (
                      <span key={stop.id}>{stop.name}</span>
                    ))}
                  </div>

                  {routeLegs.length ? (
                    <div className="route-legs">
                      {routeLegs.map((leg, index) => (
                        <article key={`${leg.from.id}-${leg.to.id}-${index}`}>
                          <strong>
                            {index + 1}. {leg.from.name}
                          </strong>
                          <p>Continue to {leg.to.name}</p>
                          <small>{formatDistance(leg.distanceMeters)}</small>
                        </article>
                      ))}
                    </div>
                  ) : null}
                </div>
              ) : (
                <p className="subtle">
                  Select a destination and run a route search to see the campus path.
                </p>
              )}
            </article>
          </div>

          <div className="dashboard-column">
            <article className="panel">
              <div className="panel-head">
                <div>
                  <h3>System status</h3>
                  <p>Every navigation action below uses the same safe campus focus logic.</p>
                </div>
              </div>

              <div className="status-grid">
                <div className="status-card">
                  <span>GPS state</span>
                  <strong>
                    {position
                      ? userOnCampus
                        ? "Live and on campus"
                        : "Live but outside campus"
                      : loadingLocation
                        ? "Waiting for fix"
                        : "No live fix"}
                  </strong>
                </div>
                <div className="status-card">
                  <span>Data source</span>
                  <strong>{dataMode === "backend" ? "Live backend" : "Validated Parul fallback"}</strong>
                </div>
                <div className="status-card">
                  <span>Campus focus</span>
                  <strong>{nearestCampusLocation?.location?.name || anchorLocation?.name || "PU Circle"}</strong>
                </div>
                <div className="status-card">
                  <span>Geo message</span>
                  <strong>{geolocationError || "Tracking is ready when available"}</strong>
                </div>
              </div>

              <p className="system-note">{dataNote}</p>
            </article>

            <article className="panel">
              <div className="panel-head">
                <div>
                  <h3>Search and browse</h3>
                  <p>Search by building, hostel, library, food point, or alias.</p>
                </div>
              </div>

              <input
                className="search-input"
                placeholder="Search Parul buildings, hostels, food courts, or landmarks"
                value={searchValue}
                onChange={(event) => setSearchValue(event.target.value)}
              />

              <div className="location-list">
                {loadingLocations ? (
                  <p className="subtle">Loading validated campus data...</p>
                ) : filteredLocations.length ? (
                  filteredLocations.map((location) => (
                    <button
                      key={location.id}
                      type="button"
                      className={
                        selectedLocationId === location.id ? "location-item active" : "location-item"
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
                <div>
                  <h3>Selected place</h3>
                  <p>Details, facilities, and one-tap routing actions for the current selection.</p>
                </div>
              </div>

              {selectedLocation ? (
                <div className="details-block">
                  <h4>{selectedLocation.name}</h4>
                  <p>{selectedLocation.description}</p>

                  <div className="detail-meta">
                    <span>{selectedLocation.type}</span>
                    <span>
                      {selectedLocation.lat.toFixed(6)}, {selectedLocation.lng.toFixed(6)}
                    </span>
                  </div>

                  <div className="facility-chips">
                    {selectedLocation.facilities.map((facility) => (
                      <span key={facility}>{facility}</span>
                    ))}
                  </div>

                  <div className="detail-actions">
                    <button
                      type="button"
                      className="primary-button"
                      onClick={() => setDestinationId(selectedLocation.id)}
                    >
                      Use as destination
                    </button>
                    <button
                      type="button"
                      className="ghost-button"
                      onClick={() => {
                        setSourceMode("manual");
                        setSourceId(selectedLocation.id);
                      }}
                    >
                      Use as source
                    </button>
                  </div>
                </div>
              ) : (
                <p className="subtle">Select a marker or location to inspect it.</p>
              )}
            </article>

            <article className="panel">
              <div className="panel-head">
                <div>
                  <h3>Nearby from focus</h3>
                  <p>
                    {userOnCampus
                      ? "Showing places nearest to your live campus position."
                      : "Showing places nearest to the validated Parul campus anchor."}
                  </p>
                </div>
              </div>

              {nearbyLocations.length ? (
                <div className="nearby-list">
                  {nearbyLocations.map((location) => (
                    <button
                      key={location.id}
                      type="button"
                      className="nearby-card"
                      onClick={() => setSelectedLocationId(location.id)}
                    >
                      <strong>{location.name}</strong>
                      <span>{location.type}</span>
                      <small>{formatDistance(location.distanceMeters)}</small>
                    </button>
                  ))}
                </div>
              ) : (
                <p className="subtle">
                  {geolocationError || "Nearby campus suggestions will appear here."}
                </p>
              )}
            </article>
          </div>
        </section>
      </main>

      <AssistantWidget
        userPosition={campusPosition}
        locations={locations}
        userOnCampus={userOnCampus}
        fallbackMode={dataMode !== "backend"}
      />
    </div>
  );
}

export default DashboardPage;
