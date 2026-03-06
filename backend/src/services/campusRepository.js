const Location = require("../models/Location");
const { isDatabaseConnected } = require("../config/db");
const { campusSeedLocations } = require("../data/campusSeed");

let seedSyncPromise = null;

function normalizeConnectionIds(connections) {
  if (!Array.isArray(connections)) {
    return [];
  }

  return [...new Set(connections.map((value) => String(value).toLowerCase()))];
}

function normalizeLocation(location) {
  const guideX = Number(location.guideX);
  const guideY = Number(location.guideY);
  return {
    id: String(location.id).toLowerCase(),
    name: location.name,
    type: String(location.type).toLowerCase(),
    description: location.description || "",
    aliases: Array.isArray(location.aliases) ? location.aliases : [],
    lat: Number(location.lat),
    lng: Number(location.lng),
    guideX: Number.isFinite(guideX) ? guideX : null,
    guideY: Number.isFinite(guideY) ? guideY : null,
    facilities: Array.isArray(location.facilities) ? location.facilities : [],
    connections: normalizeConnectionIds(location.connections),
  };
}

async function syncSeedData() {
  if (!isDatabaseConnected()) {
    return;
  }

  if (!seedSyncPromise) {
    seedSyncPromise = (async () => {
      const operations = campusSeedLocations.map((location) => {
        const normalized = normalizeLocation(location);
        return {
          updateOne: {
            filter: { id: normalized.id },
            update: { $set: normalized },
            upsert: true,
          },
        };
      });

      const seedIds = campusSeedLocations.map((location) =>
        String(location.id).toLowerCase(),
      );
      await Location.bulkWrite(operations, { ordered: false });
      await Location.deleteMany({ id: { $nin: seedIds } });
      console.log(`[db] Synced ${operations.length} campus locations.`);
    })().finally(() => {
      seedSyncPromise = null;
    });
  }

  await seedSyncPromise;
}

async function getAllLocations() {
  if (isDatabaseConnected()) {
    await syncSeedData();

    const dbLocations = await Location.find().lean().sort({ name: 1 });
    return dbLocations.map(normalizeLocation);
  }

  return campusSeedLocations.map(normalizeLocation);
}

async function getLocationById(id) {
  const normalizedId = String(id || "").toLowerCase();
  const locations = await getAllLocations();
  return locations.find((location) => location.id === normalizedId) || null;
}

module.exports = {
  getAllLocations,
  getLocationById,
};
