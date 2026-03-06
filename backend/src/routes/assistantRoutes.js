const express = require("express");
const { getAllLocations } = require("../services/campusRepository");
const { generateAssistantReply } = require("../services/assistantService");

const router = express.Router();

router.post("/chat", async (req, res, next) => {
  try {
    const { message, userPosition } = req.body || {};
    const locations = await getAllLocations();
    const payload = generateAssistantReply({
      message,
      userPosition,
      locations,
    });

    res.json(payload);
  } catch (error) {
    next(error);
  }
});

module.exports = router;

