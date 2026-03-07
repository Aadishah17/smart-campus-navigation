import parulCampusLocations, { PARUL_DEFAULT_SOURCE_ID } from "../data/parulCampusLocations";

const EARTH_RADIUS_METERS = 6371000;

function toRadians(value) {
  return (value * Math.PI) / 180;
}

export function haversineDistanceMeters(lat1, lng1, lat2, lng2) {
  const dLat = toRadians(lat2 - lat1);
  const dLng = toRadians(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRadians(lat1)) *
      Math.cos(toRadians(lat2)) *
      Math.sin(dLng / 2) *
      Math.sin(dLng / 2);

  return EARTH_RADIUS_METERS * (2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a)));
}

function estimateWalkMinutes(distanceMeters, walkingSpeedMetersPerSecond = 1.35) {
  const minutes = distanceMeters / (walkingSpeedMetersPerSecond * 60);
  return Math.max(1, Math.round(minutes));
}

function uniqueStrings(values) {
  return Array.from(new Set(values.filter(Boolean)));
}

export function normalizeLocations(locations) {
  if (!Array.isArray(locations)) {
    return [];
  }

  return locations
    .map((location) => ({
      id: String(location.id || "").trim().toLowerCase(),
      name: String(location.name || "").trim(),
      type: String(location.type || "facility").trim().toLowerCase(),
      description: String(location.description || "").trim(),
      aliases: Array.isArray(location.aliases)
        ? uniqueStrings(location.aliases.map((alias) => String(alias).trim().toLowerCase()))
        : [],
      lat: Number(location.lat),
      lng: Number(location.lng),
      guideX: Number.isFinite(Number(location.guideX)) ? Number(location.guideX) : null,
      guideY: Number.isFinite(Number(location.guideY)) ? Number(location.guideY) : null,
      facilities: Array.isArray(location.facilities)
        ? uniqueStrings(location.facilities.map((facility) => String(facility).trim()))
        : [],
      connections: Array.isArray(location.connections)
        ? uniqueStrings(location.connections.map((connection) => String(connection).trim().toLowerCase()))
        : [],
    }))
    .filter(
      (location) =>
        location.id &&
        location.name &&
        Number.isFinite(location.lat) &&
        Number.isFinite(location.lng),
    );
}

export function campusCenter(locations) {
  const source = locations.length ? locations : parulCampusLocations;
  const totals = source.reduce(
    (state, location) => ({
      lat: state.lat + location.lat,
      lng: state.lng + location.lng,
    }),
    { lat: 0, lng: 0 },
  );

  return {
    lat: totals.lat / source.length,
    lng: totals.lng / source.length,
  };
}

export function campusAnchor(locations, preferredId = PARUL_DEFAULT_SOURCE_ID) {
  const source = locations.length ? locations : parulCampusLocations;
  return (
    source.find((location) => location.id === preferredId) ||
    source.find((location) => location.id === PARUL_DEFAULT_SOURCE_ID) ||
    source[0]
  );
}

export function findNearestLocation(locations, { lat, lng }) {
  if (!Number.isFinite(lat) || !Number.isFinite(lng) || !locations.length) {
    return null;
  }

  let nearest = null;

  locations.forEach((location) => {
    const distanceMeters = haversineDistanceMeters(lat, lng, location.lat, location.lng);
    if (!nearest || distanceMeters < nearest.distanceMeters) {
      nearest = { location, distanceMeters };
    }
  });

  return nearest;
}

export function isOnCampus(locations, position, paddingMeters = 180) {
  if (!position || !Number.isFinite(position.lat) || !Number.isFinite(position.lng)) {
    return false;
  }

  const source = locations.length ? locations : parulCampusLocations;
  let minLat = source[0].lat;
  let maxLat = source[0].lat;
  let minLng = source[0].lng;
  let maxLng = source[0].lng;

  source.slice(1).forEach((location) => {
    minLat = Math.min(minLat, location.lat);
    maxLat = Math.max(maxLat, location.lat);
    minLng = Math.min(minLng, location.lng);
    maxLng = Math.max(maxLng, location.lng);
  });

  const midLatRadians = toRadians((minLat + maxLat) / 2);
  const latPadding = paddingMeters / 111320;
  const lngPadding =
    paddingMeters / (111320 * Math.max(Math.abs(Math.cos(midLatRadians)), 0.2));

  return (
    position.lat >= minLat - latPadding &&
    position.lat <= maxLat + latPadding &&
    position.lng >= minLng - lngPadding &&
    position.lng <= maxLng + lngPadding
  );
}

export function findNearbyLocations(
  locations,
  { lat, lng, radiusMeters = 900, limit = 8, predicate = null },
) {
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
    return [];
  }

  return locations
    .filter((location) => !predicate || predicate(location))
    .map((location) => ({
      ...location,
      distanceMeters: haversineDistanceMeters(lat, lng, location.lat, location.lng),
    }))
    .filter((location) => location.distanceMeters <= radiusMeters)
    .sort((left, right) => left.distanceMeters - right.distanceMeters)
    .slice(0, limit)
    .map((location) => ({
      ...location,
      distanceMeters: Number(location.distanceMeters.toFixed(2)),
    }));
}

function connectGraphEdge(graph, locationMap, fromId, toId) {
  if (fromId === toId) {
    return;
  }

  const from = locationMap.get(fromId);
  const to = locationMap.get(toId);
  if (!from || !to) {
    return;
  }

  const neighbors = graph.get(fromId);
  if (neighbors.some((neighbor) => neighbor.targetId === toId)) {
    return;
  }

  neighbors.push({
    targetId: toId,
    distanceMeters: haversineDistanceMeters(from.lat, from.lng, to.lat, to.lng),
  });
}

function connectedComponents(graph) {
  const visited = new Set();
  const components = [];

  graph.forEach((_, nodeId) => {
    if (visited.has(nodeId)) {
      return;
    }

    const stack = [nodeId];
    const component = [];
    visited.add(nodeId);

    while (stack.length) {
      const currentId = stack.pop();
      component.push(currentId);

      (graph.get(currentId) || []).forEach((neighbor) => {
        if (visited.has(neighbor.targetId)) {
          return;
        }

        visited.add(neighbor.targetId);
        stack.push(neighbor.targetId);
      });
    }

    components.push(component);
  });

  return components;
}

export function buildGraph(locations) {
  const locationMap = new Map(locations.map((location) => [location.id, location]));
  const graph = new Map(locations.map((location) => [location.id, []]));
  const nearestNeighborCount = locations.length >= 40 ? 4 : 3;

  locations.forEach((location) => {
    (location.connections || []).forEach((targetId) => {
      connectGraphEdge(graph, locationMap, location.id, targetId);
      connectGraphEdge(graph, locationMap, targetId, location.id);
    });

    locations
      .filter((candidate) => candidate.id !== location.id)
      .map((candidate) => ({
        id: candidate.id,
        distanceMeters: haversineDistanceMeters(
          location.lat,
          location.lng,
          candidate.lat,
          candidate.lng,
        ),
      }))
      .sort((left, right) => left.distanceMeters - right.distanceMeters)
      .slice(0, nearestNeighborCount)
      .forEach((candidate) => {
        connectGraphEdge(graph, locationMap, location.id, candidate.id);
        connectGraphEdge(graph, locationMap, candidate.id, location.id);
      });
  });

  let components = connectedComponents(graph);
  while (components.length > 1) {
    let bestBridge = null;

    for (let sourceIndex = 0; sourceIndex < components.length; sourceIndex += 1) {
      for (
        let targetIndex = sourceIndex + 1;
        targetIndex < components.length;
        targetIndex += 1
      ) {
        components[sourceIndex].forEach((fromId) => {
          components[targetIndex].forEach((toId) => {
            const from = locationMap.get(fromId);
            const to = locationMap.get(toId);
            const distanceMeters = haversineDistanceMeters(
              from.lat,
              from.lng,
              to.lat,
              to.lng,
            );

            if (!bestBridge || distanceMeters < bestBridge.distanceMeters) {
              bestBridge = { fromId, toId, distanceMeters };
            }
          });
        });
      }
    }

    if (!bestBridge) {
      break;
    }

    connectGraphEdge(graph, locationMap, bestBridge.fromId, bestBridge.toId);
    connectGraphEdge(graph, locationMap, bestBridge.toId, bestBridge.fromId);
    components = connectedComponents(graph);
  }

  return graph;
}

export function buildNetworkEdges(locations) {
  const graph = buildGraph(locations);
  const seen = new Set();
  const edges = [];

  graph.forEach((neighbors, fromId) => {
    neighbors.forEach((neighbor) => {
      const key =
        fromId.localeCompare(neighbor.targetId) <= 0
          ? `${fromId}|${neighbor.targetId}`
          : `${neighbor.targetId}|${fromId}`;

      if (seen.has(key)) {
        return;
      }

      seen.add(key);
      edges.push([fromId, neighbor.targetId]);
    });
  });

  return edges;
}

class MinPriorityQueue {
  constructor() {
    this.heap = [];
  }

  get size() {
    return this.heap.length;
  }

  push(value, priority) {
    this.heap.push({ value, priority });
    this.bubbleUp(this.heap.length - 1);
  }

  pop() {
    if (!this.heap.length) {
      return null;
    }

    const top = this.heap[0];
    const end = this.heap.pop();

    if (this.heap.length) {
      this.heap[0] = end;
      this.bubbleDown(0);
    }

    return top;
  }

  bubbleUp(index) {
    let cursor = index;

    while (cursor > 0) {
      const parentIndex = Math.floor((cursor - 1) / 2);
      if (this.heap[parentIndex].priority <= this.heap[cursor].priority) {
        break;
      }

      [this.heap[parentIndex], this.heap[cursor]] = [
        this.heap[cursor],
        this.heap[parentIndex],
      ];
      cursor = parentIndex;
    }
  }

  bubbleDown(index) {
    let cursor = index;

    while (true) {
      const left = 2 * cursor + 1;
      const right = 2 * cursor + 2;
      let smallest = cursor;

      if (left < this.heap.length && this.heap[left].priority < this.heap[smallest].priority) {
        smallest = left;
      }

      if (right < this.heap.length && this.heap[right].priority < this.heap[smallest].priority) {
        smallest = right;
      }

      if (smallest === cursor) {
        break;
      }

      [this.heap[smallest], this.heap[cursor]] = [
        this.heap[cursor],
        this.heap[smallest],
      ];
      cursor = smallest;
    }
  }
}

export function calculateRoute({
  locations,
  destinationId,
  sourceId = null,
  sourcePosition = null,
}) {
  const safeLocations = locations.length ? locations : parulCampusLocations;
  const locationMap = new Map(safeLocations.map((location) => [location.id, location]));
  const destination = locationMap.get(String(destinationId || "").toLowerCase());

  if (!destination) {
    return null;
  }

  let normalizedSourceId = String(sourceId || "").toLowerCase();
  let sourceFromPosition = null;

  if (
    sourcePosition &&
    Number.isFinite(sourcePosition.lat) &&
    Number.isFinite(sourcePosition.lng)
  ) {
    sourceFromPosition = findNearestLocation(safeLocations, sourcePosition);
    normalizedSourceId = sourceFromPosition?.location?.id || normalizedSourceId;
  }

  if (!normalizedSourceId) {
    normalizedSourceId = campusAnchor(safeLocations).id;
  }

  const source = locationMap.get(normalizedSourceId);
  if (!source) {
    return null;
  }

  const graph = buildGraph(safeLocations);
  const distances = new Map();
  const previous = new Map();
  const queue = new MinPriorityQueue();

  graph.forEach((_, nodeId) => {
    distances.set(nodeId, Number.POSITIVE_INFINITY);
    previous.set(nodeId, null);
  });

  distances.set(source.id, 0);
  queue.push(source.id, 0);

  while (queue.size > 0) {
    const current = queue.pop();
    if (!current) {
      break;
    }

    if (current.priority > distances.get(current.value)) {
      continue;
    }

    if (current.value === destination.id) {
      break;
    }

    (graph.get(current.value) || []).forEach((neighbor) => {
      const candidateDistance = distances.get(current.value) + neighbor.distanceMeters;
      if (candidateDistance < distances.get(neighbor.targetId)) {
        distances.set(neighbor.targetId, candidateDistance);
        previous.set(neighbor.targetId, current.value);
        queue.push(neighbor.targetId, candidateDistance);
      }
    });
  }

  if (distances.get(destination.id) === Number.POSITIVE_INFINITY) {
    return null;
  }

  const pathIds = [];
  let cursor = destination.id;

  while (cursor) {
    pathIds.unshift(cursor);
    cursor = previous.get(cursor);
  }

  const path = pathIds.map((id) => locationMap.get(id)).filter(Boolean);
  const totalDistanceMeters = distances.get(destination.id);

  return {
    source,
    destination,
    sourceFromPosition: sourceFromPosition
      ? {
          location: sourceFromPosition.location,
          distanceMeters: Number(sourceFromPosition.distanceMeters.toFixed(2)),
        }
      : null,
    pathIds,
    path,
    totalDistanceMeters: Number(totalDistanceMeters.toFixed(2)),
    totalDistanceKm: Number((totalDistanceMeters / 1000).toFixed(2)),
    estimatedWalkMinutes: estimateWalkMinutes(totalDistanceMeters),
  };
}

export function buildRouteLegs(path) {
  if (!Array.isArray(path) || path.length < 2) {
    return [];
  }

  return path.slice(0, -1).map((location, index) => ({
    from: location,
    to: path[index + 1],
    distanceMeters: Number(
      haversineDistanceMeters(
        location.lat,
        location.lng,
        path[index + 1].lat,
        path[index + 1].lng,
      ).toFixed(2),
    ),
  }));
}

export function formatDistance(distanceMeters) {
  if (!Number.isFinite(distanceMeters)) {
    return "--";
  }

  return distanceMeters >= 1000
    ? `${(distanceMeters / 1000).toFixed(2)} km`
    : `${Math.round(distanceMeters)} m`;
}

function bestMatchByType(locations, position, predicate) {
  const nearby = findNearbyLocations(locations, {
    lat: position.lat,
    lng: position.lng,
    radiusMeters: 1800,
    limit: 5,
    predicate,
  });

  return nearby[0] || null;
}

function findMentionedLocation(locations, message) {
  const lowerMessage = message.toLowerCase();

  return (
    locations.find(
      (location) =>
        lowerMessage.includes(location.name.toLowerCase()) ||
        lowerMessage.includes(location.id) ||
        location.aliases.some((alias) => lowerMessage.includes(alias)),
    ) || null
  );
}

export function assistantReply({
  locations,
  message,
  userPosition = null,
  userOnCampus = true,
}) {
  const safeLocations = locations.length ? locations : parulCampusLocations;
  const trimmedMessage = String(message || "").trim();
  const lowerMessage = trimmedMessage.toLowerCase();
  const anchor = campusAnchor(safeLocations);
  const referencePosition =
    userOnCampus && userPosition ? userPosition : { lat: anchor.lat, lng: anchor.lng };
  const nearby = findNearbyLocations(safeLocations, {
    lat: referencePosition.lat,
    lng: referencePosition.lng,
    radiusMeters: 1200,
    limit: 5,
  });
  const nearest = nearby[0] || null;
  const mentionedLocation = findMentionedLocation(safeLocations, lowerMessage);

  if (!trimmedMessage) {
    return {
      reply:
        "Ask about nearby places, route planning, libraries, hostels, food courts, or a specific Parul University building.",
      nearby,
      nearest,
    };
  }

  if (!userOnCampus && (lowerMessage.includes("where am i") || lowerMessage.includes("my location"))) {
    return {
      reply: `Your GPS appears outside the mapped Parul University campus, so I am keeping navigation focused near ${anchor.name}.`,
      nearby,
      nearest,
    };
  }

  if (lowerMessage.includes("where am i") || lowerMessage.includes("my location")) {
    return nearest
      ? {
          reply: `You are closest to ${nearest.name} (${formatDistance(nearest.distanceMeters)} away).`,
          nearby,
          nearest,
        }
      : {
          reply:
            "I could not resolve your current campus position yet, so the map is staying centered on Parul University.",
          nearby,
          nearest,
        };
  }

  if (lowerMessage.includes("nearby") || lowerMessage.includes("nearest")) {
    if (!nearby.length) {
      return {
        reply: "I do not have nearby campus matches right now.",
        nearby,
        nearest,
      };
    }

    return {
      reply: `Closest campus places: ${nearby
        .slice(0, 3)
        .map((location) => `${location.name} (${formatDistance(location.distanceMeters)})`)
        .join(", ")}.`,
      nearby,
      nearest,
    };
  }

  if (mentionedLocation) {
    return {
      reply: `${mentionedLocation.name}: ${mentionedLocation.description} Facilities: ${mentionedLocation.facilities.join(", ")}.`,
      nearby,
      nearest,
    };
  }

  if (lowerMessage.includes("food") || lowerMessage.includes("canteen") || lowerMessage.includes("coffee")) {
    const spot = bestMatchByType(safeLocations, referencePosition, (location) => location.type === "dining");
    return {
      reply: spot
        ? `Nearest dining option is ${spot.name} (${formatDistance(spot.distanceMeters)} away).`
        : "I could not find a dining destination right now.",
      nearby,
      nearest,
    };
  }

  if (lowerMessage.includes("library")) {
    const spot = bestMatchByType(
      safeLocations,
      referencePosition,
      (location) => location.type === "library" || location.name.toLowerCase().includes("library"),
    );
    return {
      reply: spot
        ? `Closest library option is ${spot.name} (${formatDistance(spot.distanceMeters)} away).`
        : "I could not find a campus library right now.",
      nearby,
      nearest,
    };
  }

  if (lowerMessage.includes("hostel") || lowerMessage.includes("residence")) {
    const spot = bestMatchByType(
      safeLocations,
      referencePosition,
      (location) => location.type === "residential",
    );
    return {
      reply: spot
        ? `Nearest residential block is ${spot.name} (${formatDistance(spot.distanceMeters)} away).`
        : "I could not find a hostel block right now.",
      nearby,
      nearest,
    };
  }

  if (lowerMessage.includes("help") || lowerMessage.includes("route") || lowerMessage.includes("what can you do")) {
    return {
      reply:
        "I can help you find nearby buildings, identify your campus area, suggest food or library spots, and route you between mapped Parul University locations.",
      nearby,
      nearest,
    };
  }

  return {
    reply:
      "Try asking for nearby places, your current campus area, the nearest food court, hostel, or a building name like Administrative Block, C. V. Raman Center, or Tagore Bhawan.",
    nearby,
    nearest,
  };
}

export function isLikelyParulDataset(locations, maxCenterDriftMeters = 1200) {
  if (!locations.length) {
    return false;
  }

  const candidateCenter = campusCenter(locations);
  const parulCenter = campusCenter(parulCampusLocations);

  return (
    haversineDistanceMeters(
      candidateCenter.lat,
      candidateCenter.lng,
      parulCenter.lat,
      parulCenter.lng,
    ) <= maxCenterDriftMeters
  );
}

export { parulCampusLocations };
