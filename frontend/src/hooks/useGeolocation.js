import { useEffect, useState } from "react";

function useGeolocation() {
  const geolocationSupported =
    typeof navigator !== "undefined" && "geolocation" in navigator;

  const [position, setPosition] = useState(null);
  const [error, setError] = useState(
    geolocationSupported ? "" : "Geolocation is not supported in this browser.",
  );
  const [permissionDenied, setPermissionDenied] = useState(false);
  const [loading, setLoading] = useState(geolocationSupported);

  useEffect(() => {
    if (!geolocationSupported) {
      return undefined;
    }

    const watchId = navigator.geolocation.watchPosition(
      (geoPosition) => {
        setPosition({
          lat: geoPosition.coords.latitude,
          lng: geoPosition.coords.longitude,
        });
        setError("");
        setPermissionDenied(false);
        setLoading(false);
      },
      (geoError) => {
        setLoading(false);
        if (geoError.code === 1) {
          setPermissionDenied(true);
          setError("Location permission denied. Enable GPS for live navigation.");
        } else {
          setError("Unable to fetch current location.");
        }
      },
      {
        enableHighAccuracy: true,
        maximumAge: 8000,
        timeout: 8000,
      },
    );

    return () => {
      navigator.geolocation.clearWatch(watchId);
    };
  }, [geolocationSupported]);

  return {
    position,
    error,
    permissionDenied,
    loading,
  };
}

export default useGeolocation;
