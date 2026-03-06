const { findNearbyLocations } = require("./graphService");

function formatDistance(distanceMeters) {
  if (distanceMeters >= 1000) {
    return `${(distanceMeters / 1000).toFixed(2)} km`;
  }
  return `${Math.round(distanceMeters)} m`;
}

function findMentionedLocation(message, locations) {
  const lower = message.toLowerCase();

  return (
    locations.find(
      (location) =>
        lower.includes(location.name.toLowerCase()) ||
        lower.includes(location.id) ||
        (Array.isArray(location.aliases) &&
          location.aliases.some((alias) =>
            lower.includes(String(alias).toLowerCase()),
          )),
    ) || null
  );
}

function generateAssistantReply({ message, userPosition, locations }) {
  const safeMessage = String(message || "").trim();
  const lowerMessage = safeMessage.toLowerCase();
  const hasUserPosition =
    userPosition &&
    Number.isFinite(userPosition.lat) &&
    Number.isFinite(userPosition.lng);

  const nearby = hasUserPosition
    ? findNearbyLocations(userPosition.lat, userPosition.lng, locations, 1200, 5)
    : [];
  const nearest = nearby[0] || null;
  const mentionedLocation = findMentionedLocation(lowerMessage, locations);

  if (!safeMessage) {
    return {
      reply:
        "Ask me where you are, nearby places, or details about a specific building.",
      nearby,
      nearest,
    };
  }

  if (lowerMessage.includes("where am i") || lowerMessage.includes("my location")) {
    if (!nearest) {
      return {
        reply:
          "I need GPS permission to detect your current area. Please allow location access in your browser.",
        nearby,
        nearest,
      };
    }

    return {
      reply: `You are closest to ${nearest.name} (${formatDistance(
        nearest.distanceMeters,
      )} away).`,
      nearby,
      nearest,
    };
  }

  if (lowerMessage.includes("nearby") || lowerMessage.includes("nearest")) {
    if (!nearby.length) {
      return {
        reply:
          "I cannot detect nearby places right now. Please enable GPS access and try again.",
        nearby,
        nearest,
      };
    }

    const placeList = nearby
      .slice(0, 3)
      .map((location, index) => {
        return `${index + 1}. ${location.name} (${formatDistance(
          location.distanceMeters,
        )})`;
      })
      .join(" ");

    return {
      reply: `Nearest places: ${placeList}`,
      nearby,
      nearest,
    };
  }

  if (mentionedLocation) {
    const facilities =
      mentionedLocation.facilities.length > 0
        ? mentionedLocation.facilities.join(", ")
        : "No facilities listed";

    return {
      reply: `${mentionedLocation.name}: ${mentionedLocation.description} Facilities: ${facilities}.`,
      nearby,
      nearest,
    };
  }

  if (lowerMessage.includes("help") || lowerMessage.includes("what can you do")) {
    return {
      reply:
        "I can help with nearby places, current location, and building information. Example: 'nearest food court' or 'tell me about A24'.",
      nearby,
      nearest,
    };
  }

  return {
    reply:
      "Try asking for nearby places, your current location, or a building name such as Central Library, A24, or G7.",
    nearby,
    nearest,
  };
}

module.exports = { generateAssistantReply };
