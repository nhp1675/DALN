// UI contract tests use API fixtures. They do NOT validate MongoDB or replace integration tests.

export const ids = {
  movie: "111111111111111111111111",
  cinema: "222222222222222222222222",
  show: "333333333333333333333333",
  room: "444444444444444444444444",
  order: "555555555555555555555555",
  user: "666666666666666666666666",
  ticket: "777777777777777777777777",
};
export async function fixture(page, role = "customer") {
  const policy = {
    holdMinutes: 10,
    changeCutoffHours: 24,
    refundPercent: 100,
    pointsPerVnd: 10000,
  };
  const movies = [
    {
      _id: ids.movie,
      title: "Quỹ đạo cuối cùng",
      genre: "Khoa học viễn tưởng",
      duration: 128,
      synopsis:
        "Một tín hiệu từ rìa vũ trụ đưa phi hành gia trẻ đến hành tinh nơi thời gian dường như đã dừng lại.",
      cast: "Minh Anh, Hoàng Nam",
      director: "Trần Hải",
      ageRating: "T13",
      poster: "/posters/orbit.svg",
      status: "now",
    },
    ...["Mùa hè bên em", "Thành phố không ngủ", "Khu vườn trên mây"].map(
      (title, i) => ({
        _id: String(i + 8).repeat(24),
        title,
        genre: [
          "Tình cảm · Thanh xuân",
          "Hành động · Trinh thám",
          "Hoạt hình · Gia đình",
        ][i],
        duration: 106 + i * 5,
        synopsis: "Một bộ phim cho trải nghiệm điện ảnh trọn vẹn.",
        ageRating: "P",
        poster: "/posters/" + ["summer", "city", "garden"][i] + ".svg",
        status: "now",
      }),
    ),
  ];
  const cinema = {
    _id: ids.cinema,
    name: "CineGo Hà Đông",
    city: "Hà Nội",
    address: "Khu đô thị Văn Phú, Hà Đông, Hà Nội (rạp mẫu)",
    latitude: 20.96,
    longitude: 105.76,
    active: true,
  };
  const show = {
    _id: ids.show,
    movieId: ids.movie,
    cinemaId: ids.cinema,
    roomId: ids.room,
    startAt: new Date(Date.now() + 72 * 3600000).toISOString(),
    endAt: new Date(Date.now() + 74 * 3600000).toISOString(),
    standardPrice: 80000,
    vipPrice: 110000,
    status: "active",
  };
  const room = { _id: ids.room, name: "Phòng 01 · 2D", cinemaId: ids.cinema };
  const seats = Array.from({ length: 70 }, (_, i) => ({
    id: (1000 + i).toString(16).padStart(24, "0"),
    label: String.fromCharCode(65 + Math.floor(i / 10)) + ((i % 10) + 1),
    type: i < 30 ? "standard" : "vip",
    price: i < 30 ? 80000 : 110000,
    status: i === 15 ? "booked" : "available",
  }));
  let order = null,
    tickets = [];
  const messages = [];
  await page.route("**/api/**", async (route) => {
    const req = route.request(),
      url = new URL(req.url()),
      p = url.pathname.replace("/api", "");
    const body = req.postDataJSON?.();
    let result,
      status = 200;
    if (p === "/auth/me")
      result = {
        user: {
          id: ids.user,
          name: "Nguyễn Hồng Phong",
          email: "phong@example.test",
          phone: "",
          role,
          points: 8,
        },
        csrf: "ui-csrf",
      };
    else if (p === "/config") result = { paymentMode: "demo", policy };
    else if (p === "/movies") result = movies;
    else if (p.startsWith("/movies/"))
      result = movies.find((m) => m._id === p.split("/").pop());
    else if (p === "/cinemas") result = [cinema];
    else if (p === "/showtimes") result = [show];
    else if (p.endsWith("/seats")) result = { showtime: show, room, seats };
    else if (p === "/orders" && req.method() === "POST") {
      const chosen = seats.filter((s) => body.seatIds.includes(s.id));
      order = {
        _id: ids.order,
        showtimeId: ids.show,
        userId: ids.user,
        status: "pending",
        kind: "booking",
        total: chosen.reduce((n, s) => n + s.price, 0),
        expiresAt: new Date(Date.now() + 600000).toISOString(),
        policy,
        createdAt: new Date().toISOString(),
        chosen,
      };
      result = order;
      status = 201;
    } else if (p === "/orders") result = order ? [order] : [];
    else if (p.endsWith("/pay-demo")) {
      if (body.outcome === "success") {
        order.status = "paid";
        tickets = order.chosen.map((s) => ({
          _id: ids.ticket,
          userId: ids.user,
          orderId: ids.order,
          showtimeId: ids.show,
          showtimeSeatId: s.id,
          currentValue: s.price,
          qr: "u".repeat(43),
          status: "valid",
          policy,
        }));
      }
      result = order;
    } else if (p.startsWith("/orders/"))
      result = {
        order,
        items: [],
        seats: order?.chosen || [],
        show,
        movie: movies[0],
        cinema,
        payments: [],
        requests: [],
      };
    else if (p === "/tickets")
      result = {
        tickets,
        shows: [show],
        movies,
        cinemas: [cinema],
        seats: seats.map((s) => ({ ...s, _id: s.id })),
        refunds: [],
      };
    else if (p === "/admin/overview")
      result = { users: 12, tickets: 18, pending: 2, net: 1750000 };
    else if (p.startsWith("/admin/data/")) {
      const name = p.split("/").pop();
      const items =
        {
          movies,
          cinemas: [cinema],
          rooms: [room],
          seats: seats.map((s) => ({
            ...s,
            _id: s.id,
            roomId: ids.room,
            active: true,
          })),
          showtimes: [show],
          orders: [],
          users: [],
          payments: [],
          refunds: [],
          audits: [],
        }[name] || [];
      result = { items, total: items.length, pages: 1, page: 1 };
    } else if (p.startsWith("/chat/") && p.endsWith("/messages")) {
      if (req.method() === "POST") {
        messages.push({
          _id: "m" + messages.length,
          userId: ids.user,
          name: "Phong",
          body: body.body,
          createdAt: new Date().toISOString(),
        });
        result = messages.at(-1);
        status = 201;
      } else result = messages;
    } else {
      result = { message: "Unexpected fixture " + p };
      status = 500;
    }
    await route.fulfill({
      status,
      contentType: "application/json",
      body: JSON.stringify(result),
    });
  });
  return { ids };
}
