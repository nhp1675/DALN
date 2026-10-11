// Khóa nhận diện một phim: tên + đạo diễn, không phân biệt hoa thường,
// dấu tiếng Việt hay khoảng trắng thừa. Dùng để chặn thêm trùng phim.
export const normalize = (s) =>
  String(s ?? "")
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/đ/g, "d")
    .replace(/\s+/g, " ")
    .trim();
export const movieKey = (m) => `${normalize(m.title)}|${normalize(m.director)}`;
