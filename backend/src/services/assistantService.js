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
        "Ask me where you are, nearby places, route help, or details about any mapped Parul University building.",
      nearby,
      nearest,
    };
  }

  if (lowerMessage.includes("where am i") || lowerMessage.includes("my location")) {
    if (!nearest) {
      return {
        reply:
          "I need a valid campus GPS fix to detect your current area. Please allow location access in your browser.",
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
          "I cannot detect nearby campus places right now. Please enable GPS access and try again.",
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

  if (
    lowerMessage.includes("food") ||
    lowerMessage.includes("canteen") ||
    lowerMessage.includes("coffee")
  ) {
    const foodOptions = nearby.filter((location) => location.type === "dining");
    const bestFoodOption = foodOptions[0] || null;
    return {
      reply: bestFoodOption
        ? `Nearest dining option is ${bestFoodOption.name} (${formatDistance(bestFoodOption.distanceMeters)} away).`
        : "I could not find a nearby food destination right now.",
      nearby,
      nearest,
    };
  }

  if (lowerMessage.includes("library")) {
    const libraryOption =
      locations.find((location) => location.name.toLowerCase().includes("library")) || null;
    return {
      reply: libraryOption
        ? `${libraryOption.name} is available as a mapped campus library destination.`
        : "I could not find a mapped campus library right now.",
      nearby,
      nearest,
    };
  }

  if (lowerMessage.includes("hostel") || lowerMessage.includes("residence")) {
    const residenceOption =
      locations.find(
        (location) =>
          location.type === "residential" ||
          location.name.toLowerCase().includes("residence"),
      ) || null;
    return {
      reply: residenceOption
        ? `A nearby residential option is ${residenceOption.name}.`
        : "I could not find a mapped hostel or residence right now.",
      nearby,
      nearest,
    };
  }

  if (lowerMessage.includes("help") || lowerMessage.includes("what can you do")) {
    return {
      reply:
        "I can help with nearby places, your campus area, food courts, libraries, hostels, and building information. Example: 'nearest food court' or 'tell me about Administrative Block'.",
      nearby,
      nearest,
    };
  }

  return {
    reply:
      "Try asking for nearby places, your current location, the nearest food court, or a building name such as Administrative Block, C. V. Raman Center, or Tagore Bhawan.",
    nearby,
    nearest,
  };
}

module.exports = { generateAssistantReply };
