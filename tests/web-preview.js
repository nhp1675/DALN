// Preview the release build with the application's real HTTP security headers.
// Playwright intercepts API requests; this server never connects to MongoDB.
process.env.NODE_ENV = 'test';
process.env.MONGODB_URI = 'mongodb://127.0.0.1:27017/cinego_ui_unused';
process.env.SESSION_SECRET = 'ui-fixture-only-'.repeat(6);
process.env.APP_ORIGIN = 'http://127.0.0.1:4173';
process.env.PAYMENT_MODE = 'demo';
const { app } = await import('../server/app.js');
app.listen(4173, '127.0.0.1');
