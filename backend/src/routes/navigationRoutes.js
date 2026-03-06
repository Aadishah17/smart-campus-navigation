const express = require("express");
const { getAllLocations } = require("../services/campusRepository");
const {
  buildGraph,
  dijkstra,
  findNearbyLocations,
  findNearestLocation,
  toRouteSummary,
} = require("../services/graphService");

const router = express.Router();

router.get("/graph", async (req, res, next) => {
  try {
    const locations = await getAllLocations();
    const graph = buildGraph(locations);

    const graphObject = {};
    graph.forEach((neighbors, id) => {
      graphObject[id] = neighbors;
    });

    res.json({
      nodeCount: locations.length,
      graph: graphObject,
    });
  } catch (error) {
    next(error);
  }
});

router.get("/nearby", async (req, res, next) => {
  try {
    const lat = Number(req.query.lat);
    const lng = Number(req.query.lng);
    const radius = Number(req.query.radius || 800);
    const limit = Number(req.query.limit || 5);

    if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
      return res
        .status(400)
        .json({ message: "Query params lat and lng must be valid numbers." });
    }

    const locations = await getAllLocations();
    const nearby = findNearbyLocations(lat, lng, locations, radius, limit);
    return res.json({
      count: nearby.length,
      data: nearby,
    });
  } catch (error) {
    return next(error);
  }
});

router.post("/route", async (req, res, next) => {
  try {
    const { sourceId, destinationId, sourcePosition } = req.body || {};
    const normalizedDestinationId = String(destinationId || "").toLowerCase();

    if (!normalizedDestinationId) {
      return res.status(400).json({ message: "destinationId is required." });
    }

    const locations = await getAllLocations();
    const graph = buildGraph(locations);
    const locationMap = new Map(locations.map((location) => [location.id, location]));

    if (!locationMap.has(normalizedDestinationId)) {
      return res.status(404).json({ message: "Destination location not found." });
    }

    let normalizedSourceId = String(sourceId || "").toLowerCase();
    let sourceFromPosition = null;

    if (
      sourcePosition &&
      Number.isFinite(Number(sourcePosition.lat)) &&
      Number.isFinite(Number(sourcePosition.lng))
    ) {
      sourceFromPosition = findNearestLocation(
        Number(sourcePosition.lat),
        Number(sourcePosition.lng),
        locations,
      );

      if (sourceFromPosition) {
        normalizedSourceId = sourceFromPosition.location.id;
      }
    }

    if (!normalizedSourceId) {
      return res
        .status(400)
        .json({ message: "sourceId or valid sourcePosition is required." });
    }

    if (!locationMap.has(normalizedSourceId)) {
      return res.status(404).json({ message: "Source location not found." });
    }

    const routeResult = dijkstra(graph, normalizedSourceId, normalizedDestinationId);

    if (!routeResult) {
      return res.status(404).json({ message: "No route found between locations." });
    }

    const summary = toRouteSummary(
      locations,
      routeResult.pathIds,
      routeResult.totalDistanceMeters,
    );

    return res.json({
      source: locationMap.get(normalizedSourceId),
      destination: locationMap.get(normalizedDestinationId),
      sourceFromPosition: sourceFromPosition
        ? {
            location: sourceFromPosition.location,
            distanceMeters: Number(sourceFromPosition.distanceMeters.toFixed(2)),
          }
        : null,
      pathIds: routeResult.pathIds,
      ...summary,
    });
  } catch (error) {
    return next(error);
  }
});

module.exports = router;

