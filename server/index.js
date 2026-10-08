import mongoose from "mongoose";
import { config } from "./config.js";
import { allModels } from "./models.js";
import { app } from "./app.js";
import { releaseExpired } from "./services/booking.js";
await mongoose.connect(config.MONGODB_URI, { serverSelectionTimeoutMS: 10000 });
const hello = await mongoose.connection.db.admin().command({ hello: 1 });
if (!hello.setName && hello.msg !== "isdbgrid")
  throw Error(
    "MongoDB must be a replica set (transactions required). Follow README.",
  );
await Promise.all(allModels.map((m) => m.init()));
await releaseExpired();
let cleaning = false;
const cleanup = setInterval(async () => {
  if (cleaning) return;
  cleaning = true;
  try {
    await releaseExpired();
  } catch (e) {
    console.error("Hold cleanup failed; will retry.");
  } finally {
    cleaning = false;
  }
}, 15000);
cleanup.unref();
const server = app.listen(config.PORT, "0.0.0.0", () =>
  console.log(
    `CineGo API listening on port ${config.PORT}; payment mode=${config.PAYMENT_MODE}`,
  ),
);
for (const event of ["SIGINT", "SIGTERM"])
  process.once(event, () => {
    clearInterval(cleanup);
    server.close(async () => {
      await mongoose.disconnect();
      process.exit(0);
    });
  });
