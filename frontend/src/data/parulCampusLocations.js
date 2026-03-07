export const PARUL_DEFAULT_SOURCE_ID = "pu-circle";

const rawCampusLocations = [
  ["parul-ayurved-hospital", "Parul Ayurved Hospital", 22.288583, 73.364833],
  ["main-food-court", "Main Food Court", 22.288788, 73.364878],
  ["pu-circle", "PU Circle", 22.2886, 73.364554],
  [
    "faculty-of-engineering-and-technology",
    "Faculty of Engineering and Technology",
    22.288629,
    73.364104,
  ],
  ["administrative-block", "Administrative Block", 22.288727, 73.36395],
  ["fet-diploma-studies", "FET Diploma Studies", 22.288866, 73.364084],
  ["super-market", "Super Market", 22.289858, 73.36457],
  ["mr-puff", "Mr. Puff", 22.289858, 73.36457],
  ["tea-post", "Tea Post", 22.289858, 73.36457],
  ["pu-fitness-gym", "PU Fitness Gym", 22.289858, 73.36457],
  ["campus-stationery", "Campus Stationery", 22.289953, 73.364734],
  ["pu-temple", "PU Temple", 22.290561, 73.36499],
  ["shastri-bhawan-a", "Shastri Bhawan A", 22.290561, 73.36499],
  ["shastri-bhawan-b-c", "Shastri Bhawan B/C", 22.290872, 73.365156],
  ["faculty-of-homoeopathy", "Faculty of Homoeopathy", 22.290654, 73.365498],
  ["faculty-of-pharmacy", "Faculty of Pharmacy", 22.290667, 73.366187],
  [
    "parul-polytechnic-institute",
    "Parul Polytechnic Institute",
    22.290667,
    73.366187,
  ],
  ["sarojini-bhawan-a", "Sarojini Bhawan A", 22.291016, 73.366619],
  ["sarojini-bhawan-b", "Sarojini Bhawan B", 22.291394, 73.36662],
  ["u-k-laundry", "U.K. Laundry", 22.291121, 73.366487],
  ["school-of-pharmacy", "School of Pharmacy", 22.291218, 73.366317],
  ["marie-curie-residence", "Marie Curie Residence", 22.291127, 73.365871],
  ["mess-4", "Mess 4", 22.29185, 73.367308],
  ["indira-bhawan-b", "Indira Bhawan B", 22.29199, 73.366879],
  ["indira-bhawan-a", "Indira Bhawan A", 22.29201, 73.366354],
  ["indira-bhawan-c", "Indira Bhawan C", 22.291819, 73.366309],
  [
    "dr-r-c-shah-medical-library",
    "Dr. R. C. Shah Medical Library",
    22.292118,
    73.366348,
  ],
  [
    "albert-einstein-residence",
    "Albert Einstein Residence",
    22.291786,
    73.365924,
  ],
  ["kalam-bhawan-a", "Kalam Bhawan A", 22.291679, 73.365262],
  ["kalam-bhawan-b", "Kalam Bhawan B", 22.291634, 73.365453],
  ["kalam-bhawan-c", "Kalam Bhawan C", 22.291632, 73.365595],
  ["tagore-bhawan-a", "Tagore Bhawan A", 22.291887, 73.364802],
  ["kathi-junction", "Kathi Junction", 22.292006, 73.364786],
  ["tilak-bhawan-b", "Tilak Bhawan B", 22.29238, 73.36504],
  ["tilak-bhawan-a", "Tilak Bhawan A", 22.291857, 73.365086],
  ["mess-3", "Mess 3", 22.292419, 73.36533],
  ["janki-bhawan", "Janki Bhawan", 22.292419, 73.36533],
  ["domino-s", "Domino's", 22.291174, 73.364777],
  ["mess-1", "Mess 1", 22.291146, 73.365158],
  ["faculty-of-pharmacy-pip", "Faculty of Pharmacy PIP", 22.288047, 73.364829],
  ["security-office", "Security Office", 22.287767, 73.364261],
  ["car-parking-west", "Car Parking West", 22.288163, 73.363286],
  ["bike-parking", "Bike Parking", 22.288028, 73.362745],
  [
    "faculty-of-management-studies",
    "Faculty of Management Studies",
    22.288409,
    73.362913,
  ],
  ["football-ground", "Football Ground", 22.289063, 73.362821],
  [
    "parul-institute-of-ayurved",
    "Parul Institute of Ayurved",
    22.289108,
    73.363366,
  ],
  [
    "university-exam-section",
    "University Exam Section",
    22.289235,
    73.363545,
  ],
  ["management-studies-annex", "Management Studies Annex", 22.288924, 73.362367],
  ["kalpana-bhawan-a", "Kalpana Bhawan A", 22.289387, 73.362063],
  ["kalpana-bhawan-b", "Kalpana Bhawan B", 22.289528, 73.361812],
  ["krishna-food-canteen", "Krishna Food Canteen", 22.289862, 73.361261],
  ["milkha-bhawan-a", "Milkha Bhawan A", 22.289149, 73.361017],
  [
    "parul-institute-of-architecture-and-planning",
    "Parul Institute of Architecture and Planning",
    22.289926,
    73.36197,
  ],
  ["car-parking-east", "Car Parking East", 22.290286, 73.361881],
  ["annapurna-bhavan", "Annapurna Bhavan", 22.290442, 73.362692],
  ["bhagat-singh-bhawan", "Bhagat Singh Bhawan", 22.291574, 73.363222],
  ["champion-s-cove", "Champion's Cove", 22.291858, 73.36232],
  ["c-v-raman-center", "C. V. Raman Center", 22.292229, 73.363089],
  [
    "subhash-chandra-bose-bhawan",
    "Subhash Chandra Bose Bhawan",
    22.292926,
    73.362244,
  ],
  [
    "green-house-and-crop-cafeteria",
    "Green House and Crop Cafeteria",
    22.293258,
    73.362101,
  ],
  ["bus-stop", "Bus Stop", 22.293709, 73.362178],
  ["tagore-bhawan-b", "Tagore Bhawan B", 22.292492, 73.363636],
];

function inferType(name) {
  const lowerName = name.toLowerCase();

  if (lowerName.includes("hospital")) {
    return "hospital";
  }
  if (lowerName.includes("parking")) {
    return "parking";
  }
  if (lowerName.includes("library")) {
    return "library";
  }
  if (
    lowerName.includes("mess") ||
    lowerName.includes("canteen") ||
    lowerName.includes("food") ||
    lowerName.includes("domino") ||
    lowerName.includes("tea") ||
    lowerName.includes("junction") ||
    lowerName.includes("market") ||
    lowerName.includes("puff") ||
    lowerName.includes("cafeteria")
  ) {
    return "dining";
  }
  if (lowerName.includes("temple")) {
    return "landmark";
  }
  if (lowerName.includes("gym") || lowerName.includes("ground")) {
    return "sports";
  }
  if (lowerName.includes("security") || lowerName.includes("administrative")) {
    return "admin";
  }
  if (lowerName.includes("circle") || lowerName.includes("bus stop")) {
    return "transport";
  }
  if (
    lowerName.includes("bhawan") ||
    lowerName.includes("residence") ||
    lowerName.includes("hostel") ||
    lowerName.includes("laundry")
  ) {
    return "residential";
  }
  if (
    lowerName.includes("faculty") ||
    lowerName.includes("institute") ||
    lowerName.includes("school") ||
    lowerName.includes("section")
  ) {
    return "academic";
  }
  if (lowerName.includes("stationery")) {
    return "retail";
  }

  return "facility";
}

function buildDescription(name, type) {
  switch (type) {
    case "hospital":
      return `${name} is a mapped healthcare destination on the Parul University campus.`;
    case "parking":
      return `${name} helps visitors and students park close to the surrounding campus zone.`;
    case "library":
      return `${name} provides study and reference support within the campus academic district.`;
    case "dining":
      return `${name} is a campus food and refreshment point for students, staff, and visitors.`;
    case "sports":
      return `${name} is part of the Parul University activity and recreation area.`;
    case "admin":
      return `${name} supports administration, security, or student service access inside the campus.`;
    case "transport":
      return `${name} is a useful orientation and movement landmark for navigating the Parul University campus.`;
    case "residential":
      return `${name} is part of the residential and student living zone on campus.`;
    case "academic":
      return `${name} is a mapped academic destination used for teaching, learning, or examinations.`;
    case "retail":
      return `${name} supports day-to-day student convenience inside the campus.`;
    default:
      return `${name} is a mapped point of interest on the Parul University campus.`;
  }
}

function buildFacilities(type) {
  switch (type) {
    case "hospital":
      return ["Reception", "Clinical Services", "Emergency Support"];
    case "parking":
      return ["Vehicle Access", "Parking Bays", "Drop-off Point"];
    case "library":
      return ["Reading Space", "Reference Desk", "Study Support"];
    case "dining":
      return ["Food Counter", "Seating", "Refreshments"];
    case "sports":
      return ["Open Space", "Activity Zone", "Campus Recreation"];
    case "admin":
      return ["Help Desk", "Administrative Support", "Information Point"];
    case "transport":
      return ["Wayfinding Landmark", "Pickup Point", "Campus Access"];
    case "residential":
      return ["Student Housing", "Residential Access", "Daily Living Support"];
    case "academic":
      return ["Classrooms", "Department Access", "Student Services"];
    case "retail":
      return ["Supplies", "Quick Purchase", "Student Convenience"];
    default:
      return ["Campus Landmark"];
  }
}

function buildAliases(id, name) {
  const lowerName = name.toLowerCase();
  const normalizedName = lowerName.replace(/[^a-z0-9\s]/g, " ").replace(/\s+/g, " ").trim();
  const aliases = new Set([id, lowerName, normalizedName]);

  if (lowerName.includes("pu")) {
    aliases.add(lowerName.replace(/\bpu\b/g, "parul university").replace(/\s+/g, " ").trim());
  }
  if (lowerName.includes("bhawan")) {
    aliases.add(lowerName.replace("bhawan", "hostel"));
  }
  if (lowerName.includes("canteen") || lowerName.includes("mess")) {
    aliases.add("food");
  }
  if (lowerName.includes("pharmacy")) {
    aliases.add("pharmacy");
  }
  if (lowerName.includes("library")) {
    aliases.add("library");
  }
  if (lowerName.includes("parking")) {
    aliases.add("parking");
  }
  if (lowerName.includes("circle")) {
    aliases.add("center");
    aliases.add("main circle");
  }

  return Array.from(aliases).filter(Boolean);
}

export const parulCampusLocations = rawCampusLocations.map(([id, name, lat, lng]) => {
  const type = inferType(name);

  return {
    id,
    name,
    type,
    description: buildDescription(name, type),
    aliases: buildAliases(id, name),
    lat,
    lng,
    guideX: null,
    guideY: null,
    facilities: buildFacilities(type),
    connections: [],
  };
});

export default parulCampusLocations;
