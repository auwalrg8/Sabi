export default function handler(req, res) {
  res.status(200).json({
    status: 'ok',
    version: '1.0.0',
    timestamp: new Date().toISOString(),
    service: 'sabi-wallet-api',
  });
}
