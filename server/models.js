import mongoose from "mongoose";
const { Schema } = mongoose;
const id = { type: Schema.Types.ObjectId, required: true };
const text = { type: String, required: true };
const money = {
  type: Number,
  required: true,
  min: 0,
  validate: Number.isSafeInteger,
};
function model(name, shape, indexes = []) {
  const schema = new Schema(shape, { timestamps: true, strict: "throw" });
  for (const [keys, options] of indexes) schema.index(keys, options);
  return mongoose.model(name, schema);
}
export const User = model(
  "User",
  {
    name: text,
    email: { ...text, lowercase: true },
    phone: { type: String, default: "" },
    passwordHash: text,
    role: { type: String, enum: ["customer", "admin"], default: "customer" },
    active: { type: Boolean, default: true },
    netSpend: { type: Number, default: 0 },
    bookingRevision: { type: Number, default: 0 },
  },
  [[{ email: 1 }, { unique: true }]],
);
export const Session = model(
  "Session",
  {
    tokenHash: text,
    userId: id,
    csrf: text,
    expiresAt: { type: Date, required: true },
  },
  [
    [{ tokenHash: 1 }, { unique: true }],
    [{ expiresAt: 1 }, { expireAfterSeconds: 0 }],
  ],
);
export const Movie = model(
  "Movie",
  {
    title: text,
    genre: text,
    duration: { type: Number, required: true, min: 1 },
    synopsis: text,
    cast: { type: String, default: "" },
    director: { type: String, default: "" },
    ageRating: {
      type: String,
      enum: ["P", "K", "T13", "T16", "T18"],
      default: "P",
    },
    status: { type: String, enum: ["now", "soon", "archived"], default: "now" },
    poster: { type: String, default: "" },
    releaseDate: Date,
    revision: { type: Number, default: 0 },
  },
  [[{ title: "text", genre: "text" }, {}]],
);
export const Cinema = model("Cinema", {
  name: text,
  address: text,
  city: text,
  latitude: { type: Number, required: true },
  longitude: { type: Number, required: true },
  active: { type: Boolean, default: true },
  revision: { type: Number, default: 0 },
});
export const Room = model(
  "Room",
  { cinemaId: id, name: text, revision: { type: Number, default: 0 } },
  [[{ cinemaId: 1, name: 1 }, { unique: true }]],
);
export const Seat = model(
  "Seat",
  {
    roomId: id,
    label: text,
    row: text,
    number: { type: Number, required: true },
    type: { type: String, enum: ["standard", "vip"], default: "standard" },
    active: { type: Boolean, default: true },
  },
  [[{ roomId: 1, label: 1 }, { unique: true }]],
);
export const Showtime = model(
  "Showtime",
  {
    movieId: id,
    roomId: id,
    cinemaId: id,
    startAt: { type: Date, required: true },
    endAt: { type: Date, required: true },
    status: { type: String, enum: ["active", "cancelled"], default: "active" },
    standardPrice: money,
    vipPrice: money,
    revision: { type: Number, default: 0 },
  },
  [[{ roomId: 1, startAt: 1 }, {}]],
);
export const ShowtimeSeat = model(
  "ShowtimeSeat",
  {
    showtimeId: id,
    seatId: id,
    label: text,
    type: text,
    price: money,
    status: {
      type: String,
      enum: ["available", "held", "booked"],
      default: "available",
    },
    orderId: Schema.Types.ObjectId,
    holdUntil: Date,
    ticketId: Schema.Types.ObjectId,
  },
  [
    [{ showtimeId: 1, seatId: 1 }, { unique: true }],
    [{ showtimeId: 1, label: 1 }, { unique: true }],
  ],
);
export const Order = model(
  "Order",
  {
    userId: id,
    showtimeId: id,
    kind: { type: String, enum: ["booking", "exchange"], default: "booking" },
    status: {
      type: String,
      enum: ["pending", "paid", "expired", "cancelled"],
      default: "pending",
    },
    total: money,
    expiresAt: { type: Date, required: true },
    idempotencyKey: text,
    policy: { type: Schema.Types.Mixed, required: true },
    exchangeTicketId: Schema.Types.ObjectId,
    oldShowtimeSeatId: Schema.Types.ObjectId,
    newValue: Number,
    refundAmount: Number,
  },
  [
    [{ userId: 1, idempotencyKey: 1 }, { unique: true }],
    [{ status: 1, expiresAt: 1 }, {}],
  ],
);
export const OrderItem = model(
  "OrderItem",
  { orderId: id, showtimeSeatId: id, price: money },
  [[{ orderId: 1, showtimeSeatId: 1 }, { unique: true }]],
);
export const Ticket = model(
  "Ticket",
  {
    userId: id,
    orderId: id,
    orderItemId: id,
    showtimeId: id,
    showtimeSeatId: id,
    qr: text,
    status: {
      type: String,
      enum: ["valid", "used", "cancelled"],
      default: "valid",
    },
    currentValue: money,
    usedAt: Date,
    policy: { type: Schema.Types.Mixed, required: true },
  },
  [
    [{ qr: 1 }, { unique: true }],
    [{ orderItemId: 1 }, { unique: true }],
    [
      { showtimeSeatId: 1 },
      { unique: true, partialFilterExpression: { status: "valid" } },
    ],
  ],
);
export const Payment = model(
  "Payment",
  {
    userId: id,
    orderId: id,
    amount: money,
    status: { type: String, enum: ["success", "failed"], required: true },
    provider: { type: String, default: "demo" },
    reference: text,
    purpose: text,
  },
  [[{ reference: 1 }, { unique: true }]],
);
export const Allocation = model(
  "Allocation",
  {
    ticketId: id,
    paymentId: id,
    amount: money,
    refunded: { type: Number, default: 0 },
  },
  [[{ ticketId: 1, paymentId: 1 }, { unique: true }]],
);
export const Refund = model("Refund", {
  ticketId: id,
  paymentId: id,
  requestId: id,
  amount: money,
  status: {
    type: String,
    enum: ["success", "pending", "failed"],
    default: "success",
  },
  provider: { type: String, default: "demo" },
});
export const ChangeRequest = model("ChangeRequest", {
  userId: id,
  ticketId: id,
  type: { type: String, enum: ["cancel", "exchange"], required: true },
  status: {
    type: String,
    enum: ["pending", "completed", "failed"],
    required: true,
  },
  oldSeatId: id,
  newSeatId: Schema.Types.ObjectId,
  orderId: Schema.Types.ObjectId,
  difference: { type: Number, default: 0 },
  policy: { type: Schema.Types.Mixed, required: true },
});
export const ChatRoom = model("ChatRoom", { showtimeId: id, locked: {type: Boolean, default: false}, revision: {type: Number, default: 0} }, [
  [{ showtimeId: 1 }, { unique: true }],
]);
export const Membership = model("Membership", { userId: id, chatRoomId: id }, [
  [{ userId: 1, chatRoomId: 1 }, { unique: true }],
]);
export const ChatBan = model("ChatBan", {chatRoomId: id, userId: id, reason: text}, [
  [{chatRoomId: 1, userId: 1}, {unique: true}],
]);
export const Message = model(
  "Message",
  { chatRoomId: id, userId: id, name: text, body: text, hidden: {type: Boolean, default: false} },
  [[{ chatRoomId: 1, createdAt: -1 }, {}]],
);
export const Audit = model("Audit", {
  userId: Schema.Types.ObjectId,
  action: text,
  entityId: Schema.Types.ObjectId,
  details: { type: Schema.Types.Mixed, default: {} },
});
export const allModels = [
  User,
  Session,
  Movie,
  Cinema,
  Room,
  Seat,
  Showtime,
  ShowtimeSeat,
  Order,
  OrderItem,
  Ticket,
  Payment,
  Allocation,
  Refund,
  ChangeRequest,
  ChatRoom,
  ChatBan,
  Membership,
  Message,
  Audit,
];
