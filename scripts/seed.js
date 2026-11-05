export async function seed() {
  throw new Error("Đã tắt seed demo. Dùng scripts/cgv-database.js theo HUONG-DAN.md.");
}
if (process.argv[1]?.endsWith("seed.js")) await seed();
