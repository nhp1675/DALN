import mongoose from "mongoose";
import { config } from "../server/config.js";
import { allModels, Movie, Cinema, Showtime } from "../server/models.js";
import { saveRoom, saveShowtime } from "../server/services/catalog.js";
export async function seed() {
  await Promise.all(allModels.map((m) => m.init()));
  if (await Movie.countDocuments())
    return console.log("Seed skipped: movies already exist. No data deleted.");
  const movies = await Movie.create([
    {
      title: "Quỹ đạo cuối cùng",
      genre: "Khoa học viễn tưởng",
      duration: 128,
      synopsis:
        "Một tín hiệu từ rìa vũ trụ đưa phi hành gia trẻ đến hành tinh nơi thời gian dường như đã dừng lại. Giữa khoảng không vô tận, cô phải chọn giữa hành trình trở về và bí mật có thể thay đổi nhân loại.",
      cast: "Minh Anh, Hoàng Nam",
      director: "Trần Hải",
      ageRating: "T13",
      poster: "/posters/orbit.svg",
      status: "now",
    },
    {
      title: "Mùa hè bên em",
      genre: "Tình cảm · Thanh xuân",
      duration: 106,
      synopsis:
        "Hai người bạn gặp lại ở thị trấn ven biển, cùng viết tiếp mùa hè còn dang dở của tuổi hai mươi. Một câu chuyện nhỏ về những điều chưa kịp nói và lòng can đảm để bắt đầu lại.",
      cast: "Lan Chi, Khánh Duy",
      director: "Nguyễn An",
      ageRating: "T13",
      poster: "/posters/summer.svg",
      status: "now",
    },
    {
      title: "Thành phố không ngủ",
      genre: "Hành động · Trinh thám",
      duration: 115,
      synopsis:
        "Giữa những con phố ngập ánh đèn, một thám tử lần theo bí mật đằng sau vụ mất tích lúc nửa đêm. Mỗi manh mối đưa anh đến gần hơn với một sự thật không ai muốn nhắc lại.",
      cast: "Quốc Bảo, Mai Linh",
      director: "Lê Minh",
      ageRating: "T16",
      poster: "/posters/city.svg",
      status: "now",
    },
    {
      title: "Khu vườn trên mây",
      genre: "Hoạt hình · Gia đình",
      duration: 92,
      synopsis:
        "Một hạt mầm biết nói dẫn cô bé Mi đến khu vườn lơ lửng trên mây. Cùng những người bạn kỳ lạ, Mi học cách chăm sóc điều nhỏ bé để làm nên phép màu.",
      cast: "Lồng tiếng: Bảo Ngọc, Hải Đăng",
      director: "Vũ Bình",
      ageRating: "P",
      poster: "/posters/garden.svg",
      status: "now",
    },
    {
      title: "Phía bên kia bình minh",
      genre: "Phiêu lưu",
      duration: 120,
      synopsis:
        "Ba người bạn lên đường tìm ngọn hải đăng cuối cùng. Chuyến đi xuyên qua núi rừng giúp họ khám phá điều mình thực sự tìm kiếm.",
      cast: "Thanh Hằng, Đức Anh",
      director: "Phạm Sơn",
      ageRating: "K",
      poster: "/posters/dawn.svg",
      status: "soon",
    },
  ]);
  const cinemas = await Cinema.create([
    {
      name: "CineGo Hà Đông",
      city: "Hà Nội",
      address: "Khu đô thị Văn Phú, Hà Đông, Hà Nội (rạp mẫu)",
      latitude: 20.963,
      longitude: 105.766,
      active: true,
    },
    {
      name: "CineGo Cầu Giấy",
      city: "Hà Nội",
      address: "Đường Xuân Thủy, Cầu Giấy, Hà Nội (rạp mẫu)",
      latitude: 21.036,
      longitude: 105.782,
      active: true,
    },
    {
      name: "CineGo Đà Nẵng",
      city: "Đà Nẵng",
      address: "Đường Nguyễn Văn Linh, Hải Châu, Đà Nẵng (rạp mẫu)",
      latitude: 16.06,
      longitude: 108.216,
      active: true,
    },
  ]);
  for (const cinema of cinemas) {
    const room = await saveRoom(undefined, {
      cinemaId: String(cinema._id),
      name: "Phòng 01 · 2D",
      rows: 7,
      columns: 10,
    });
    for (let d = 1; d <= 7; d++) {
      const date = new Date(Date.now() + d * 86400000)
        .toISOString()
        .slice(0, 10);
      for (let m = 0; m < 4; m++)
        await saveShowtime(undefined, {
          movieId: String(movies[m]._id),
          roomId: String(room._id),
          startAt: `${date}T${String(10 + m * 3).padStart(2, "0")}:00:00+07:00`,
          standardPrice: 80000 + (d % 2) * 10000,
          vipPrice: 110000 + (d % 2) * 10000,
        });
    }
  }
  console.log(
    "Seeded fictional movies, cinemas, seats and 7 days of showtimes. No preset user passwords.",
  );
}
if (process.argv[1]?.endsWith("seed.js")) {
  await mongoose.connect(config.MONGODB_URI);
  await seed();
  await mongoose.disconnect();
}
