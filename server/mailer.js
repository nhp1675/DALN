import { config } from "./config.js";

// Gửi email. Chưa cấu hình SMTP (môi trường phát triển) thì in nội dung ra console
// để vẫn lấy được liên kết đặt lại mật khẩu khi chạy thử.
export async function sendMail({ to, subject, text }) {
  if (!config.SMTP_HOST) {
    if (config.NODE_ENV === "production") {
      console.warn("Chưa cấu hình SMTP_HOST nên không gửi được email.");
      return;
    }
    console.log(`\n[EMAIL - chưa cấu hình SMTP] Tới: ${to}\nTiêu đề: ${subject}\n${text}\n`);
    return;
  }
  const { default: nodemailer } = await import("nodemailer");
  const transport = nodemailer.createTransport({
    host: config.SMTP_HOST,
    port: config.SMTP_PORT,
    secure: config.SMTP_PORT === 465,
    auth: config.SMTP_USER
      ? { user: config.SMTP_USER, pass: config.SMTP_PASS }
      : undefined,
  });
  await transport.sendMail({
    from: config.MAIL_FROM || config.SMTP_USER,
    to,
    subject,
    text,
  });
}
