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

function buildLocationMap(locations) {
  return new Map(locations.map((location) => [location.id, location]));
}

function addGraphEdge(graph, locationMap, fromId, toId) {
  const fromNode = locationMap.get(fromId);
  const toNode = locationMap.get(toId);

  if (!fromNode || !toNode || fromId === toId) {
    return null;
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

  return distanceMeters;
}

function connectNearestNeighbors(graph, locationMap, locations) {
  const nearestNeighborCount = locations.length >= 40 ? 4 : 3;

  locations.forEach((location) => {
    const candidates = locations
      .filter((candidate) => candidate.id !== location.id)
      .map((candidate) => ({
        candidate,
        distanceMeters: haversineDistanceMeters(
          location.lat,
          location.lng,
          candidate.lat,
          candidate.lng,
        ),
      }))
      .sort((left, right) => left.distanceMeters - right.distanceMeters)
      .slice(0, nearestNeighborCount);

    candidates.forEach(({ candidate }) => {
      addGraphEdge(graph, locationMap, location.id, candidate.id);
      addGraphEdge(graph, locationMap, candidate.id, location.id);
    });
  });
}

function getConnectedComponents(graph) {
  const visited = new Set();
  const components = [];

  graph.forEach((_, nodeId) => {
    if (visited.has(nodeId)) {
      return;
    }

    const stack = [nodeId];
    const component = [];
    visited.add(nodeId);

    while (stack.length > 0) {
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

function bridgeComponents(graph, locationMap) {
  let components = getConnectedComponents(graph);

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
            const fromNode = locationMap.get(fromId);
            const toNode = locationMap.get(toId);
            const distanceMeters = haversineDistanceMeters(
              fromNode.lat,
              fromNode.lng,
              toNode.lat,
              toNode.lng,
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

    addGraphEdge(graph, locationMap, bestBridge.fromId, bestBridge.toId);
    addGraphEdge(graph, locationMap, bestBridge.toId, bestBridge.fromId);
    components = getConnectedComponents(graph);
  }
}

function buildGraph(locations) {
  const locationMap = buildLocationMap(locations);
  const graph = new Map();

  locations.forEach((location) => {
    graph.set(location.id, []);
  });

  locations.forEach((location) => {
    (location.connections || []).forEach((targetId) => {
      addGraphEdge(graph, locationMap, location.id, targetId);
      addGraphEdge(graph, locationMap, targetId, location.id);
    });
  });

  connectNearestNeighbors(graph, locationMap, locations);
  bridgeComponents(graph, locationMap);

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
