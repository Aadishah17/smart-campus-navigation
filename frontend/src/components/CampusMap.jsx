import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  CircleMarker,
  ImageOverlay,
  MapContainer,
  Polyline,
  Popup,
  TileLayer,
  Tooltip,
  useMap,
  useMapEvents,
} from "react-leaflet";
import L from "leaflet";

const MAP_IMAGE_URL = "/parul-campus-map.jpg";
const MAP_IMAGE_WIDTH = 1765;
const MAP_IMAGE_HEIGHT = 2491;
const MAP_BOUNDS = [
  [0, 0],
  [MAP_IMAGE_HEIGHT, MAP_IMAGE_WIDTH],
];
const LIVE_INITIAL_ZOOM = 17;
const LIVE_MIN_ZOOM = 15;
const LIVE_MAX_ZOOM = 20;
const LIVE_SELECTION_RADIUS_METERS = 100;
const TILE_URL = "https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png";
const TILE_SUBDOMAINS = ["a", "b", "c", "d"];
const TILE_ATTRIBUTION =
  '&copy; <a href="https://www.openstreetmap.org/copyright">OSM</a> &copy; CARTO';
const GUIDE_VIEWPORT = {
  top: 190,
  bottom: 1730,
  left: 160,
  right: 1605,
};

function projectToImagePoint(locationOrPosition, extents, options = {}) {
  const { clamp = true } = options;
  const lat = locationOrPosition.lat;
  const lng = locationOrPosition.lng;

  if (
    Number.isFinite(locationOrPosition.guideX) &&
    Number.isFinite(locationOrPosition.guideY)
  ) {
    return [locationOrPosition.guideY, locationOrPosition.guideX];
  }

  const { minLat, maxLat, minLng, maxLng } = extents;
  const latRange = maxLat - minLat || 1;
  const lngRange = maxLng - minLng || 1;

  let xRatio = (lng - minLng) / lngRange;
  let yRatio = (lat - minLat) / latRange;

  if (!clamp && (xRatio < 0 || xRatio > 1 || yRatio < 0 || yRatio > 1)) {
    return null;
  }

  xRatio = Math.max(0, Math.min(1, xRatio));
  yRatio = Math.max(0, Math.min(1, yRatio));

  return [
    GUIDE_VIEWPORT.bottom - yRatio * (GUIDE_VIEWPORT.bottom - GUIDE_VIEWPORT.top),
    GUIDE_VIEWPORT.left + xRatio * (GUIDE_VIEWPORT.right - GUIDE_VIEWPORT.left),
  ];
}

function markerStyle(type, selected) {
  if (selected) {
    return {
      radius: 10,
      color: "#ffffff",
      fillColor: "#ffffff",
      fillOpacity: 1,
      weight: 3,
    };
  }

  switch (type) {
    case "hospital":
      return { radius: 7, color: "#fff5f0", fillColor: "#e76f51", fillOpacity: 0.95, weight: 2 };
    case "academic":
      return { radius: 7, color: "#edf7f1", fillColor: "#2d6a4f", fillOpacity: 0.95, weight: 2 };
    case "residential":
      return { radius: 7, color: "#fff9ec", fillColor: "#d97706", fillOpacity: 0.95, weight: 2 };
    case "library":
      return { radius: 7, color: "#eff6ff", fillColor: "#2563eb", fillOpacity: 0.95, weight: 2 };
    case "dining":
      return { radius: 7, color: "#fff8e6", fillColor: "#ea580c", fillOpacity: 0.95, weight: 2 };
    case "sports":
      return { radius: 7, color: "#ecfccb", fillColor: "#65a30d", fillOpacity: 0.95, weight: 2 };
    case "parking":
      return { radius: 7, color: "#f8fafc", fillColor: "#475569", fillOpacity: 0.95, weight: 2 };
    case "admin":
      return { radius: 7, color: "#fff7ed", fillColor: "#9a3412", fillOpacity: 0.95, weight: 2 };
    case "transport":
      return { radius: 7, color: "#f5f3ff", fillColor: "#7c3aed", fillOpacity: 0.95, weight: 2 };
    default:
      return { radius: 7, color: "#f7fee7", fillColor: "#4d7c0f", fillOpacity: 0.95, weight: 2 };
  }
}

function computeCampusCenter(locations) {
  if (!locations.length) {
    return [22.2904, 73.3639];
  }

  const aggregate = locations.reduce(
    (state, location) => ({
      lat: state.lat + location.lat,
      lng: state.lng + location.lng,
    }),
    { lat: 0, lng: 0 },
  );

  return [aggregate.lat / locations.length, aggregate.lng / locations.length];
}

function GuideMapController({ followUser, focusPoint, onReady }) {
  const map = useMap();

  useEffect(() => {
    onReady(map);
    map.fitBounds(MAP_BOUNDS, { padding: [18, 18] });
  }, [map, onReady]);

  useEffect(() => {
    if (followUser && focusPoint) {
      map.flyTo(focusPoint, Math.max(map.getZoom(), 0), { duration: 0.8 });
    }
  }, [focusPoint, followUser, map]);

  return null;
}

function LiveMapController({ followUser, focusPosition, onReady }) {
  const map = useMap();

  useEffect(() => {
    onReady(map);
  }, [map, onReady]);

  useEffect(() => {
    if (followUser && focusPosition) {
      map.flyTo(focusPosition, Math.max(map.getZoom(), LIVE_INITIAL_ZOOM), {
        duration: 0.8,
      });
    }
  }, [focusPosition, followUser, map]);

  return null;
}

function LiveMapTapSelector({ locations, onSelectLocation }) {
  useMapEvents({
    click: (event) => {
      let nearest = null;
      let nearestMeters = Number.POSITIVE_INFINITY;

      locations.forEach((location) => {
        const meters = event.latlng.distanceTo([location.lat, location.lng]);
        if (meters < nearestMeters) {
          nearestMeters = meters;
          nearest = location;
        }
      });

      if (nearest && nearestMeters <= LIVE_SELECTION_RADIUS_METERS) {
        onSelectLocation(nearest.id);
      }
    },
  });

  return null;
}

function CampusMap({
  locations,
  campusPosition,
  routePath,
  networkEdges = [],
  selectedLocationId,
  onSelectLocation,
  followUser = false,
  focusLabel = "",
  highlightLabel = "",
  statusMessage = "",
  userOnCampus = true,
}) {
  const [mapMode, setMapMode] = useState("guide");
  const [showNetwork, setShowNetwork] = useState(true);
  const guideMapRef = useRef(null);
  const liveMapRef = useRef(null);

  const extents = useMemo(() => {
    if (!locations.length) {
      return {
        minLat: 22.2877,
        maxLat: 22.2938,
        minLng: 73.361,
        maxLng: 73.3675,
      };
    }

    return {
      minLat: Math.min(...locations.map((location) => location.lat)),
      maxLat: Math.max(...locations.map((location) => location.lat)),
      minLng: Math.min(...locations.map((location) => location.lng)),
      maxLng: Math.max(...locations.map((location) => location.lng)),
    };
  }, [locations]);

  const locationById = useMemo(
    () => new Map(locations.map((location) => [location.id, location])),
    [locations],
  );

  const projectedLocations = useMemo(
    () =>
      locations
        .map((location) => ({
          ...location,
          projectedPoint: projectToImagePoint(location, extents),
        }))
        .filter((location) => Boolean(location.projectedPoint)),
    [extents, locations],
  );

  const projectedPointById = useMemo(
    () => new Map(projectedLocations.map((location) => [location.id, location.projectedPoint])),
    [projectedLocations],
  );

  const guideNetworkSegments = useMemo(
    () =>
      networkEdges
        .map(([fromId, toId]) => {
          const fromPoint = projectedPointById.get(fromId);
          const toPoint = projectedPointById.get(toId);
          return fromPoint && toPoint ? [fromPoint, toPoint] : null;
        })
        .filter(Boolean),
    [networkEdges, projectedPointById],
  );

  const liveNetworkSegments = useMemo(
    () =>
      networkEdges
        .map(([fromId, toId]) => {
          const from = locationById.get(fromId);
          const to = locationById.get(toId);
          return from && to ? [[from.lat, from.lng], [to.lat, to.lng]] : null;
        })
        .filter(Boolean),
    [locationById, networkEdges],
  );

  const guideRouteCoordinates = useMemo(
    () =>
      routePath
        .map((point) => projectToImagePoint(point, extents))
        .filter(Boolean),
    [extents, routePath],
  );

  const liveRouteCoordinates = useMemo(
    () => routePath.map((point) => [point.lat, point.lng]),
    [routePath],
  );

  const projectedFocusPoint = useMemo(() => {
    if (!campusPosition) {
      return null;
    }

    return projectToImagePoint(campusPosition, extents, { clamp: false });
  }, [campusPosition, extents]);

  const liveFocusPosition = useMemo(
    () => (campusPosition ? [campusPosition.lat, campusPosition.lng] : null),
    [campusPosition],
  );

  const campusCenter = useMemo(() => computeCampusCenter(locations), [locations]);

  const handleGuideReady = useCallback((map) => {
    guideMapRef.current = map;
  }, []);

  const handleLiveReady = useCallback((map) => {
    liveMapRef.current = map;
  }, []);

  function handleZoomIn() {
    const map = mapMode === "guide" ? guideMapRef.current : liveMapRef.current;
    map?.zoomIn();
  }

  function handleZoomOut() {
    const map = mapMode === "guide" ? guideMapRef.current : liveMapRef.current;
    map?.zoomOut();
  }

  function handleCenter() {
    if (mapMode === "guide") {
      if (projectedFocusPoint) {
        guideMapRef.current?.flyTo(projectedFocusPoint, Math.max(guideMapRef.current.getZoom(), 0), {
          duration: 0.7,
        });
        return;
      }

      guideMapRef.current?.fitBounds(MAP_BOUNDS, { padding: [18, 18] });
      return;
    }

    if (liveFocusPosition) {
      liveMapRef.current?.flyTo(
        liveFocusPosition,
        Math.max(liveMapRef.current.getZoom(), LIVE_INITIAL_ZOOM),
        { duration: 0.8 },
      );
      return;
    }

    liveMapRef.current?.flyTo(campusCenter, LIVE_INITIAL_ZOOM, { duration: 0.8 });
  }

  function handleReset() {
    if (mapMode === "guide") {
      guideMapRef.current?.fitBounds(MAP_BOUNDS, { padding: [18, 18] });
      return;
    }

    liveMapRef.current?.setView(campusCenter, LIVE_INITIAL_ZOOM);
  }

  const mapModeMessage =
    mapMode === "guide"
      ? "Guide mode overlays Parul University locations on the campus image."
      : "Live mode uses the validated Parul campus coordinates on an interactive street map.";

  return (
    <div className="map-card">
      <div className="map-ui-overlay map-ui-overlay-top">
        <div className="map-mode-switch">
          <button
            type="button"
            className={mapMode === "guide" ? "map-chip active" : "map-chip"}
            onClick={() => setMapMode("guide")}
          >
            Guide Map
          </button>
          <button
            type="button"
            className={mapMode === "live" ? "map-chip active" : "map-chip"}
            onClick={() => setMapMode("live")}
          >
            Live Map
          </button>
        </div>

        <button
          type="button"
          className={showNetwork ? "map-chip map-chip-wide active" : "map-chip map-chip-wide"}
          onClick={() => setShowNetwork((value) => !value)}
        >
          {showNetwork ? "Path Network On" : "Path Network Off"}
        </button>

        <div className={userOnCampus ? "map-state-pill" : "map-state-pill caution"}>
          {userOnCampus ? "On-campus focus" : "Pinned to campus"}
        </div>
      </div>

      {mapMode === "guide" ? (
        <MapContainer
          crs={L.CRS.Simple}
          bounds={MAP_BOUNDS}
          maxBounds={MAP_BOUNDS}
          maxBoundsViscosity={1}
          minZoom={-1}
          maxZoom={2}
          zoomSnap={0.25}
          zoomControl={false}
          className="campus-map"
        >
          <ImageOverlay url={MAP_IMAGE_URL} bounds={MAP_BOUNDS} />
          <GuideMapController
            followUser={followUser}
            focusPoint={projectedFocusPoint}
            onReady={handleGuideReady}
          />

          {showNetwork
            ? guideNetworkSegments.map((segment, index) => (
                <Polyline
                  key={`guide-network-${index}`}
                  positions={segment}
                  pathOptions={{
                    color: "#2d6a4f",
                    weight: 2.5,
                    opacity: 0.28,
                    lineCap: "round",
                  }}
                />
              ))
            : null}

          {guideRouteCoordinates.length > 1 ? (
            <>
              <Polyline
                positions={guideRouteCoordinates}
                pathOptions={{
                  color: "#fff5e4",
                  weight: 10,
                  opacity: 0.92,
                  lineCap: "round",
                  lineJoin: "round",
                }}
              />
              <Polyline
                positions={guideRouteCoordinates}
                pathOptions={{
                  color: "#d97706",
                  weight: 5,
                  opacity: 1,
                  lineCap: "round",
                  lineJoin: "round",
                }}
              />
            </>
          ) : null}

          {projectedLocations.map((location) => (
            <CircleMarker
              key={location.id}
              center={location.projectedPoint}
              pathOptions={markerStyle(location.type, selectedLocationId === location.id)}
              eventHandlers={{ click: () => onSelectLocation(location.id) }}
            >
              <Tooltip direction="top" offset={[0, -6]}>
                {location.name}
              </Tooltip>
              <Popup>
                <h4>{location.name}</h4>
                <p>{location.description}</p>
                <button
                  type="button"
                  className={
                    selectedLocationId === location.id
                      ? "map-select-button active"
                      : "map-select-button"
                  }
                  onClick={() => onSelectLocation(location.id)}
                >
                  {selectedLocationId === location.id ? "Selected" : "Select"}
                </button>
              </Popup>
            </CircleMarker>
          ))}

          {projectedFocusPoint ? (
            <CircleMarker
              center={projectedFocusPoint}
              radius={8}
              pathOptions={{
                color: "#164e63",
                fillColor: "#22d3ee",
                fillOpacity: 1,
                weight: 3,
              }}
            >
              <Popup>{userOnCampus ? "Live focus position" : "Campus focus position"}</Popup>
            </CircleMarker>
          ) : null}
        </MapContainer>
      ) : (
        <MapContainer
          center={campusCenter}
          zoom={LIVE_INITIAL_ZOOM}
          minZoom={LIVE_MIN_ZOOM}
          maxZoom={LIVE_MAX_ZOOM}
          zoomControl={false}
          className="campus-map"
        >
          <TileLayer
            url={TILE_URL}
            subdomains={TILE_SUBDOMAINS}
            attribution={TILE_ATTRIBUTION}
          />
          <LiveMapController
            followUser={followUser}
            focusPosition={liveFocusPosition}
            onReady={handleLiveReady}
          />
          <LiveMapTapSelector locations={locations} onSelectLocation={onSelectLocation} />

          {showNetwork
            ? liveNetworkSegments.map((segment, index) => (
                <Polyline
                  key={`live-network-${index}`}
                  positions={segment}
                  pathOptions={{
                    color: "#2d6a4f",
                    weight: 2.5,
                    opacity: 0.26,
                    lineCap: "round",
                  }}
                />
              ))
            : null}

          {liveRouteCoordinates.length > 1 ? (
            <>
              <Polyline
                positions={liveRouteCoordinates}
                pathOptions={{
                  color: "#fff5e4",
                  weight: 10,
                  opacity: 0.92,
                  lineCap: "round",
                  lineJoin: "round",
                }}
              />
              <Polyline
                positions={liveRouteCoordinates}
                pathOptions={{
                  color: "#d97706",
                  weight: 5,
                  opacity: 1,
                  lineCap: "round",
                  lineJoin: "round",
                }}
              />
            </>
          ) : null}

          {locations.map((location) => (
            <CircleMarker
              key={location.id}
              center={[location.lat, location.lng]}
              pathOptions={markerStyle(location.type, selectedLocationId === location.id)}
              eventHandlers={{ click: () => onSelectLocation(location.id) }}
            >
              <Tooltip direction="top" offset={[0, -6]}>
                {location.name}
              </Tooltip>
              <Popup>
                <h4>{location.name}</h4>
                <p>{location.description}</p>
                <button
                  type="button"
                  className={
                    selectedLocationId === location.id
                      ? "map-select-button active"
                      : "map-select-button"
                  }
                  onClick={() => onSelectLocation(location.id)}
                >
                  {selectedLocationId === location.id ? "Selected" : "Select"}
                </button>
              </Popup>
            </CircleMarker>
          ))}

          {liveFocusPosition ? (
            <CircleMarker
              center={liveFocusPosition}
              radius={8}
              pathOptions={{
                color: "#164e63",
                fillColor: "#22d3ee",
                fillOpacity: 1,
                weight: 3,
              }}
            >
              <Popup>{userOnCampus ? "Live focus position" : "Campus focus position"}</Popup>
            </CircleMarker>
          ) : null}
        </MapContainer>
      )}

      <div className="map-ui-overlay map-ui-overlay-side">
        <button type="button" className="map-tool-button" onClick={handleZoomIn} aria-label="Zoom in">
          +
        </button>
        <button
          type="button"
          className="map-tool-button"
          onClick={handleZoomOut}
          aria-label="Zoom out"
        >
          -
        </button>
        <button
          type="button"
          className="map-tool-button"
          onClick={handleCenter}
          aria-label="Center map"
        >
          CTR
        </button>
        <button
          type="button"
          className="map-tool-button"
          onClick={handleReset}
          aria-label="Reset view"
        >
          RST
        </button>
      </div>

      <div className="map-overlay-stack">
        {focusLabel ? <div className="map-overlay-pill">{focusLabel}</div> : null}
        {highlightLabel ? <div className="map-overlay-pill subtle">{highlightLabel}</div> : null}
        <div className="map-overlay-note">
          <strong>{mapModeMessage}</strong>
          {statusMessage ? <span>{statusMessage}</span> : null}
        </div>
      </div>
    </div>
  );
}

export default CampusMap;
