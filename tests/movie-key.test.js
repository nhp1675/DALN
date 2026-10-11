import test from "node:test";
import assert from "node:assert/strict";
import { movieKey, normalize } from "../server/movie-key.js";

test("cùng tên và đạo diễn khác hoa thường, dấu hoặc khoảng trắng vẫn là một phim", () => {
  const a = { title: "Khóa Chặt Cửa Nào Suzume", director: "Makoto Shinkai" };
  const b = { title: "  khoa chat  CUA nao suzume ", director: "makoto  shinkai" };
  assert.equal(movieKey(a), movieKey(b));
  assert.equal(normalize("Đường Đến Ngày Vinh Quang"), "duong den ngay vinh quang");
});

test("khác tên hoặc khác đạo diễn là phim khác", () => {
  const base = { title: "Dune", director: "Denis Villeneuve" };
  assert.notEqual(movieKey(base), movieKey({ ...base, title: "Dune 2" }));
  assert.notEqual(movieKey(base), movieKey({ ...base, director: "David Lynch" }));
  assert.equal(movieKey({ title: "Dune" }), movieKey({ title: "Dune", director: "" }));
});
