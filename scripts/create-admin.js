import { createInterface } from "node:readline/promises";
import mongoose from "mongoose";
import { config } from "../server/config.js";
import { User } from "../server/models.js";
import { hashPassword } from "../server/auth.js";
const rl = createInterface({ input: process.stdin, output: process.stdout });
const email = (await rl.question("Admin email: ")).trim().toLowerCase();
const name = (await rl.question("Admin name: ")).trim();
console.log("Password will be visible in this terminal. Do not screen-share.");
const password = await rl.question("Password (at least 12 characters): ");
rl.close();
if (
  !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) ||
  name.length < 2 ||
  password.length < 12 ||
  password.length > 128
)
  throw Error("Invalid input");
await mongoose.connect(config.MONGODB_URI);
await User.init();
if (await User.exists({ email }))
  throw Error(
    "Account already exists. This command never promotes or overwrites existing users.",
  );
await User.create({
  email,
  name,
  passwordHash: await hashPassword(password),
  role: "admin",
});
console.log("Admin created.");
await mongoose.disconnect();
