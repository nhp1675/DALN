// Runs inside mongosh. Root is used only to provision a limited application user.
try {
  rs.status();
} catch (e) {
  if (e.code === 94)
    rs.initiate({ _id: "rs0", members: [{ _id: 0, host: "localhost:27017" }] });
  else throw e;
}
let primary = false;
for (let i = 0; i < 60; i++) {
  if (db.hello().isWritablePrimary) {
    primary = true;
    break;
  }
  sleep(1000);
}
if (!primary) throw Error("Replica set did not elect a primary");
const appDb = db.getSiblingDB("cinego");
if (!appDb.getUser("cinego"))
  appDb.createUser({
    user: "cinego",
    pwd: process.env.MONGO_APP_PASSWORD,
    roles: [{ role: "readWrite", db: "cinego" }],
  });
print("Replica set initialized; limited cinego user provisioned.");
