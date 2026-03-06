function toRadians(value) {
  return (value * Math.PI) / 180;
}

function haversineDistanceMeters(lat1, lng1, lat2, lng2) {
  const earthRadius = 6371000;
  const dLat = toRadians(lat2 - lat1);
  const dLng = toRadians(lng2 - lng1);

  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRadians(lat1)) *
      Math.cos(toRadians(lat2)) *
      Math.sin(dLng / 2) *
      Math.sin(dLng / 2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return earthRadius * c;
}

function buildGraph(locations) {
  const locationMap = new Map();
  const graph = new Map();

  locations.forEach((location) => {
    locationMap.set(location.id, location);
    graph.set(location.id, []);
  });

  function addEdge(fromId, toId) {
    const fromNode = locationMap.get(fromId);
    const toNode = locationMap.get(toId);

    if (!fromNode || !toNode) {
      return;
    }

    const distanceMeters = haversineDistanceMeters(
      fromNode.lat,
      fromNode.lng,
      toNode.lat,
      toNode.lng,
    );

    const fromNeighbors = graph.get(fromId);
    if (!fromNeighbors.some((item) => item.targetId === toId)) {
      fromNeighbors.push({ targetId: toId, distanceMeters });
    }
  }

  locations.forEach((location) => {
    (location.connections || []).forEach((targetId) => {
      addEdge(location.id, targetId);
      addEdge(targetId, location.id);
    });
  });

  return graph;
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
    if (this.heap.length === 0) {
      return null;
    }

    const top = this.heap[0];
    const end = this.heap.pop();

    if (this.heap.length > 0) {
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
    const length = this.heap.length;

    while (true) {
      const left = 2 * cursor + 1;
      const right = 2 * cursor + 2;
      let smallest = cursor;

      if (left < length && this.heap[left].priority < this.heap[smallest].priority) {
        smallest = left;
      }

      if (right < length && this.heap[right].priority < this.heap[smallest].priority) {
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

function dijkstra(graph, sourceId, destinationId) {
  if (!graph.has(sourceId) || !graph.has(destinationId)) {
    return null;
  }

  const distances = new Map();
  const previous = new Map();
  const queue = new MinPriorityQueue();

  graph.forEach((_, nodeId) => {
    distances.set(nodeId, Infinity);
    previous.set(nodeId, null);
  });

  distances.set(sourceId, 0);
  queue.push(sourceId, 0);

  while (queue.size > 0) {
    const current = queue.pop();
    if (!current) {
      break;
    }

    const currentNode = current.value;
    const currentDistance = current.priority;

    if (currentDistance > distances.get(currentNode)) {
      continue;
    }

    if (currentNode === destinationId) {
      break;
    }

    const neighbors = graph.get(currentNode);
    neighbors.forEach((neighbor) => {
      const candidateDistance =
        distances.get(currentNode) + neighbor.distanceMeters;
      if (candidateDistance < distances.get(neighbor.targetId)) {
        distances.set(neighbor.targetId, candidateDistance);
        previous.set(neighbor.targetId, currentNode);
        queue.push(neighbor.targetId, candidateDistance);
      }
    });
  }

  if (distances.get(destinationId) === Infinity) {
    return null;
  }

  const pathIds = [];
  let cursor = destinationId;

  while (cursor) {
    pathIds.unshift(cursor);
    cursor = previous.get(cursor);
  }

  if (pathIds[0] !== sourceId) {
    return null;
  }

  return {
    pathIds,
    totalDistanceMeters: distances.get(destinationId),
  };
}

function estimateWalkMinutes(distanceMeters, walkingSpeedMetersPerSecond = 1.4) {
  const minutes = distanceMeters / (walkingSpeedMetersPerSecond * 60);
  return Math.max(1, Math.round(minutes));
}

function toRouteSummary(locations, pathIds, totalDistanceMeters) {
  const locationMap = new Map(locations.map((location) => [location.id, location]));
  const path = pathIds.map((id) => locationMap.get(id)).filter(Boolean);
  return {
    path,
    totalDistanceMeters: Number(totalDistanceMeters.toFixed(2)),
    totalDistanceKm: Number((totalDistanceMeters / 1000).toFixed(2)),
    estimatedWalkMinutes: estimateWalkMinutes(totalDistanceMeters),
  };
}

function findNearestLocation(lat, lng, locations) {
  if (!Number.isFinite(lat) || !Number.isFinite(lng) || !locations.length) {
    return null;
  }

  let nearest = null;
  locations.forEach((location) => {
    const distanceMeters = haversineDistanceMeters(lat, lng, location.lat, location.lng);
    if (!nearest || distanceMeters < nearest.distanceMeters) {
      nearest = {
        location,
        distanceMeters,
      };
    }
  });

  return nearest;
}

function findNearbyLocations(lat, lng, locations, radiusMeters = 800, limit = 5) {
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
    return [];
  }

  return locations
    .map((location) => ({
      ...location,
      distanceMeters: haversineDistanceMeters(lat, lng, location.lat, location.lng),
    }))
    .filter((location) => location.distanceMeters <= radiusMeters)
    .sort((a, b) => a.distanceMeters - b.distanceMeters)
    .slice(0, limit)
    .map((location) => ({
      ...location,
      distanceMeters: Number(location.distanceMeters.toFixed(2)),
    }));
}

module.exports = {
  buildGraph,
  dijkstra,
  findNearestLocation,
  findNearbyLocations,
  haversineDistanceMeters,
  toRouteSummary,
};
