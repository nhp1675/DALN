import mongoose from "mongoose";
import { z } from "zod";
import { Audit } from "./models.js";
export class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}
export const fail = (status, message) => {
  throw new HttpError(status, message);
};
export const objectId = z
  .string()
  .regex(/^[a-f0-9]{24}$/i, "Mã dữ liệu không hợp lệ");
export const parseId = (x) => objectId.parse(x);
export const same = (a, b) => String(a) === String(b);
export async function transaction(fn) {
  const session = await mongoose.startSession();
  try {
    return await session.withTransaction(() => fn(session), {
      readConcern: { level: "snapshot" },
      writeConcern: { w: "majority" },
    });
  } finally {
    await session.endSession();
  }
}
export async function create(Model, data, session) {
  const [doc] = await Model.create([data], { session });
  return doc;
}
export const audit = (userId, action, entityId, session, details = {}) =>
  create(Audit, { userId, action, entityId, details }, session);
export const route = (fn) => async (req, res, next) => {
  try {
    await fn(req, res);
  } catch (e) {
    next(e);
  }
};
export const body = (schema) => (req, res, next) => {
  try {
    req.data = schema.parse(req.body);
    next();
  } catch (e) {
    next(e);
  }
};
