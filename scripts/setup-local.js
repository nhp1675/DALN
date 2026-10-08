import { existsSync, writeFileSync } from "node:fs";
import { randomBytes } from "node:crypto";
if (existsSync(".env")) {
  console.log(".env already exists; no settings or secrets were overwritten.");
  process.exit(0);
}
const secret = () => randomBytes(32).toString("hex");
const appPassword = secret();
writeFileSync(
  ".env",
  `NODE_ENV=development\nPORT=4000\nAPP_ORIGIN=http://localhost:4000\nSESSION_SECRET=${secret()}\nMONGO_ROOT_PASSWORD=${secret()}\nMONGO_APP_PASSWORD=${appPassword}\nMONGODB_URI=mongodb://cinego:${appPassword}@127.0.0.1:27017/cinego?authSource=cinego&replicaSet=rs0&directConnection=true\nPAYMENT_MODE=demo\nHOLD_MINUTES=10\nCHANGE_CUTOFF_HOURS=24\nREFUND_PERCENT=100\nPOINTS_PER_VND=10000\n`,
  { mode: 0o600, flag: "wx" },
);
console.log(
  "Created .env with random local secrets. Next: docker compose up -d",
);
