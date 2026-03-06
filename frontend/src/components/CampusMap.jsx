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
const LIVE_CENTER_FALLBACK = [23.0375, 72.5525];
const LIVE_INITIAL_ZOOM = 17;
const LIVE_MIN_ZOOM = 15;
const LIVE_MAX_ZOOM = 20;
const LIVE_SELECTION_RADIUS_METERS = 120;
const TILE_URL = "https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png";
const TILE_SUBDOMAINS = ["a", "b", "c", "d"];
const TILE_ATTRIBUTION =
  '&copy; <a href="https://www.openstreetmap.org/copyright">OSM</a> &copy; CARTO';

const CAMPUS_RECT = {
  top: 210,
  bottom: 1530,
  left: 70,
  right: 1695,
};

function projectToImagePoint(
  lat,
  lng,
  extents,
  { clamp = true } = {},
) {
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

  const x = CAMPUS_RECT.left + xRatio * (CAMPUS_RECT.right - CAMPUS_RECT.left);
  const y =
    CAMPUS_RECT.bottom - yRatio * (CAMPUS_RECT.bottom - CAMPUS_RECT.top);

  return [y, x];
}

function buildNetworkSegments(locations, toPoint) {
  const locationById = new Map(locations.map((location) => [location.id, location]));
  const segments = [];

  locations.forEach((location) => {
    const fromPoint = toPoint(location);
    if (!fromPoint) {
      return;
    }

    (location.connections || []).forEach((targetId) => {
      if (String(location.id).localeCompare(String(targetId)) >= 0) {
        return;
      }

      const target = locationById.get(targetId);
      if (!target) {
        return;
      }

      const toTargetPoint = toPoint(target);
      if (!toTargetPoint) {
        return;
      }

      segments.push([fromPoint, toTargetPoint]);
    });
  });

  return segments;
}

function computeCampusCenter(locations) {
  if (!locations.length) {
    return LIVE_CENTER_FALLBACK;
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

function getMarkerStyle(type, selected) {
  if (selected) {
    return {
      radius: 9,
      color: "#ffffff",
      fillColor: "#ffffff",
      fillOpacity: 1,
      weight: 3,
    };
  }

  if (type === "academic") {
    return {
      radius: 7,
      color: "#d9d9d9",
      fillColor: "#b8b8b8",
      fillOpacity: 0.95,
      weight: 2,
    };
  }

  if (type === "residential") {
    return {
      radius: 7,
      color: "#bfbfbf",
      fillColor: "#8a8a8a",
      fillOpacity: 0.95,
      weight: 2,
    };
  }

  if (type === "facility") {
    return {
      radius: 7,
      color: "#ececec",
      fillColor: "#9e9e9e",
      fillOpacity: 0.95,
      weight: 2,
    };
  }

  return {
    radius: 7,
    color: "#c6c6c6",
    fillColor: "#7a7a7a",
    fillOpacity: 0.95,
    weight: 2,
  };
}

function GuideMapController({ followUser, userPoint, onReady }) {
  const map = useMap();

  useEffect(() => {
    onReady(map);
    map.fitBounds(MAP_BOUNDS, { padding: [18, 18] });
  }, [map, onReady]);

  useEffect(() => {
    if (followUser && userPoint) {
      map.flyTo(userPoint, map.getZoom(), { duration: 0.75 });
    }
  }, [followUser, map, userPoint]);

  return null;
}

function LiveMapController({ followUser, userPosition, onReady }) {
  const map = useMap();

  useEffect(() => {
    onReady(map);
  }, [map, onReady]);

  useEffect(() => {
    if (followUser && userPosition) {
      map.flyTo(userPosition, Math.max(map.getZoom(), LIVE_INITIAL_ZOOM), {
        duration: 0.75,
      });
    }
  }, [followUser, map, userPosition]);

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
  userPosition,
  routePath,
  selectedLocationId,
  onSelectLocation,
  followUser = false,
}) {
  const [mapMode, setMapMode] = useState("guide");
  const [showNetwork, setShowNetwork] = useState(true);
  const guideMapRef = useRef(null);
  const liveMapRef = useRef(null);

  const extents = useMemo(() => {
    if (!locations.length) {
      return {
        minLat: 23.035,
        maxLat: 23.039,
        minLng: 72.55,
        maxLng: 72.555,
      };
    }

    return {
      minLat: Math.min(...locations.map((location) => location.lat)),
      maxLat: Math.max(...locations.map((location) => location.lat)),
      minLng: Math.min(...locations.map((location) => location.lng)),
      maxLng: Math.max(...locations.map((location) => location.lng)),
    };
  }, [locations]);

  const projectedLocations = useMemo(() => {
    return locations
      .map((location) => {
        const projectedPoint = projectToImagePoint(
          location.lat,
          location.lng,
          extents,
        );
        return { ...location, projectedPoint };
      })
      .filter((location) => Boolean(location.projectedPoint));
  }, [extents, locations]);

  const projectedLocationById = useMemo(() => {
    return new Map(
      projectedLocations.map((location) => [location.id, location.projectedPoint]),
    );
  }, [projectedLocations]);

  const projectedUserPoint = useMemo(() => {
    if (!userPosition) {
      return null;
    }

    return projectToImagePoint(userPosition.lat, userPosition.lng, extents, {
      clamp: false,
    });
  }, [extents, userPosition]);

  const liveUserPosition = useMemo(() => {
    if (!userPosition) {
      return null;
    }

    return [userPosition.lat, userPosition.lng];
  }, [userPosition]);

  const guideRouteCoordinates = useMemo(() => {
    return routePath
      .map((point) => projectToImagePoint(point.lat, point.lng, extents))
      .filter(Boolean);
  }, [extents, routePath]);

  const liveRouteCoordinates = useMemo(() => {
    return routePath.map((point) => [point.lat, point.lng]);
  }, [routePath]);

  const guideNetworkSegments = useMemo(() => {
    return buildNetworkSegments(locations, (location) =>
      projectedLocationById.get(location.id),
    );
  }, [locations, projectedLocationById]);

  const liveNetworkSegments = useMemo(() => {
    return buildNetworkSegments(locations, (location) => [location.lat, location.lng]);
  }, [locations]);

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
      guideMapRef.current?.fitBounds(MAP_BOUNDS, { padding: [18, 18] });
      return;
    }

    if (userPosition) {
      liveMapRef.current?.flyTo(
        [userPosition.lat, userPosition.lng],
        Math.max(liveMapRef.current.getZoom(), LIVE_INITIAL_ZOOM),
        { duration: 0.75 },
      );
      return;
    }

    liveMapRef.current?.flyTo(campusCenter, liveMapRef.current.getZoom(), {
      duration: 0.6,
    });
  }

  function handleReset() {
    if (mapMode === "guide") {
      guideMapRef.current?.fitBounds(MAP_BOUNDS, { padding: [18, 18] });
      return;
    }

    liveMapRef.current?.setView(campusCenter, LIVE_INITIAL_ZOOM);
  }

  const mapOverlayMessage =
    mapMode === "guide"
      ? "Guide mode: projected markers aligned to official campus guide map."
      : "Live mode: real GPS map with interactive campus graph and route overlays.";

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
          {showNetwork ? "Campus Graph: On" : "Campus Graph: Off"}
        </button>
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
            userPoint={projectedUserPoint}
            onReady={handleGuideReady}
          />

          {showNetwork
            ? guideNetworkSegments.map((segment, index) => (
                <Polyline
                  key={`guide-segment-${index}`}
                  positions={segment}
                  pathOptions={{
                    color: "#ffffff",
                    weight: 2,
                    opacity: 0.35,
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
                  color: "#000000",
                  weight: 8,
                  opacity: 0.78,
                  lineCap: "round",
                  lineJoin: "round",
                }}
              />
              <Polyline
                positions={guideRouteCoordinates}
                pathOptions={{
                  color: "#ffffff",
                  weight: 5,
                  opacity: 0.95,
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
              pathOptions={getMarkerStyle(
                location.type,
                selectedLocationId === location.id,
              )}
              eventHandlers={{
                click: () => onSelectLocation(location.id),
              }}
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

          {projectedUserPoint ? (
            <CircleMarker
              center={projectedUserPoint}
              radius={8}
              pathOptions={{
                color: "#000000",
                fillColor: "#ffffff",
                fillOpacity: 1,
                weight: 3,
              }}
            >
              <Popup>Your current location</Popup>
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
            userPosition={liveUserPosition}
            onReady={handleLiveReady}
          />
          <LiveMapTapSelector locations={locations} onSelectLocation={onSelectLocation} />

          {showNetwork
            ? liveNetworkSegments.map((segment, index) => (
                <Polyline
                  key={`live-segment-${index}`}
                  positions={segment}
                  pathOptions={{
                    color: "#ffffff",
                    weight: 2,
                    opacity: 0.35,
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
                  color: "#000000",
                  weight: 8,
                  opacity: 0.78,
                  lineCap: "round",
                  lineJoin: "round",
                }}
              />
              <Polyline
                positions={liveRouteCoordinates}
                pathOptions={{
                  color: "#ffffff",
                  weight: 5,
                  opacity: 0.95,
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
              pathOptions={getMarkerStyle(
                location.type,
                selectedLocationId === location.id,
              )}
              eventHandlers={{
                click: () => onSelectLocation(location.id),
              }}
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

          {userPosition ? (
            <CircleMarker
              center={[userPosition.lat, userPosition.lng]}
              radius={8}
              pathOptions={{
                color: "#000000",
                fillColor: "#ffffff",
                fillOpacity: 1,
                weight: 3,
              }}
            >
              <Popup>Your current location</Popup>
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

      <div className="map-overlay-note">
        {mapOverlayMessage}
      </div>
    </div>
  );
}

export default CampusMap;
