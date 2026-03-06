const express = require("express");
const { getAllLocations, getLocationById } = require("../services/campusRepository");

const router = express.Router();

router.get("/", async (req, res, next) => {
  try {
    const locations = await getAllLocations();
    res.json({
      count: locations.length,
      data: locations,
    });
  } catch (error) {
    next(error);
  }
});

router.get("/:id", async (req, res, next) => {
  try {
    const location = await getLocationById(req.params.id);

    if (!location) {
      return res.status(404).json({ message: "Location not found." });
    }

    return res.json(location);
  } catch (error) {
    return next(error);
  }
});

module.exports = router;

