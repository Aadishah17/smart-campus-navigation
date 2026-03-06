const mongoose = require("mongoose");

const locationSchema = new mongoose.Schema(
  {
    id: {
      type: String,
      required: true,
      unique: true,
      index: true,
      trim: true,
      lowercase: true,
    },
    name: {
      type: String,
      required: true,
      trim: true,
    },
    type: {
      type: String,
      required: true,
      trim: true,
      lowercase: true,
    },
    description: {
      type: String,
      default: "",
      trim: true,
    },
    aliases: {
      type: [String],
      default: [],
    },
    lat: {
      type: Number,
      required: true,
    },
    lng: {
      type: Number,
      required: true,
    },
    guideX: {
      type: Number,
      default: null,
    },
    guideY: {
      type: Number,
      default: null,
    },
    facilities: {
      type: [String],
      default: [],
    },
    connections: {
      type: [String],
      default: [],
    },
  },
  {
    timestamps: true,
  },
);

module.exports = mongoose.model("Location", locationSchema);
