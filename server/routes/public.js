import { Router } from "express";
import { z } from "zod";
import { Movie, Cinema, Showtime, ShowtimeSeat, Room } from "../models.js";
import { route, parseId, fail } from "../core.js";
import { config, policy } from "../config.js";
export const publicRouter = Router();
publicRouter.get("/config", (req, res) =>
  res.json({ paymentMode: config.PAYMENT_MODE, policy }),
);
publicRouter.get(
  "/movies",
  route(async (req, res) => {
    const q = z
      .string()
      .max(100)
      .parse(req.query.q || "");
    const status = z
      .enum(["now", "soon", "all"])
      .parse(req.query.status || "all");
    const filter = {
      status: status === "all" ? { $in: ["now", "soon"] } : status,
    };
    if (q)
      filter.$or = ["title", "genre"].map((k) => ({
        [k]: {
          $regex: q.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"),
          $options: "i",
        },
      }));
    res.json(
      await Movie.find(filter).sort({ createdAt: -1 }).limit(100).lean(),
    );
  }),
);
publicRouter.get(
  "/movies/:id",
  route(async (req, res) => {
    const m = await Movie.findOne({
      _id: parseId(req.params.id),
      status: { $ne: "archived" },
    }).lean();
    if (!m) fail(404, "Không tìm thấy phim.");
    res.json(m);
  }),
);
publicRouter.get(
  "/cinemas",
  route(async (req, res) =>
    res.json(await Cinema.find({ active: true }).lean()),
  ),
);
publicRouter.get(
  "/showtimes",
  route(async (req, res) => {
    const f = { status: "active", startAt: { $gt: new Date() } };
    for (const key of ["movieId", "cinemaId"])
      if (req.query[key]) f[key] = parseId(req.query[key]);
    if (req.query.date) {
      const date = z
        .string()
        .regex(/^\d{4}-\d{2}-\d{2}$/)
        .parse(req.query.date);
      const start = new Date(date + "T00:00:00+07:00");
      if (Number.isNaN(+start)) fail(400, "Ngày không hợp lệ.");
      f.startAt = {
        $gte: new Date(Math.max(+start, Date.now())),
        $lt: new Date(+start + 86400000),
      };
    }
    res.json(await Showtime.find(f).sort({ startAt: 1 }).limit(500).lean());
  }),
);
publicRouter.get(
  "/showtimes/:id/seats",
  route(async (req, res) => {
    const show = await Showtime.findOne({
      _id: parseId(req.params.id),
      status: "active",
    }).lean();
    if (!show) fail(404, "Suất chiếu không tồn tại.");
    const [seats, room] = await Promise.all([
      ShowtimeSeat.find({ showtimeId: show._id }).sort({ label: 1 }).lean(),
      Room.findById(show.roomId).lean(),
    ]);
    res.json({
      showtime: show,
      room,
      seats: seats.map((s) => ({
        id: s._id,
        label: s.label,
        type: s.type,
        price: s.price,
        status:
          s.status === "held" && s.holdUntil <= new Date()
            ? "available"
            : s.status,
      })),
    });
  }),
);
