# Cloudflare Worker Setup for Breez API Key

This guide explains how to securely store the Breez API key using Cloudflare Workers.

## Why Cloudflare Workers?

✅ **Security**: API key encrypted at rest in Cloudflare's infrastructure  
✅ **Version Control Safe**: No secrets in Git history  
✅ **Rotation**: Update key without redeploying app  
✅ **Access Control**: Add rate limiting or authentication as needed  
✅ **Free Tier**: 100,000 requests/day on free plan

## Setup Steps

### 1. Create Cloudflare Worker

1. Go to [Cloudflare Dashboard](https://dash.cloudflare.com/)
2. Navigate to **Workers & Pages** → **Create Application** → **Create Worker**
3. Name it: `sabi-breez-config`
4. Click **Deploy**

### 2. Add Worker Code

Replace the default code with:

```javascript
export default {
  async fetch(request, env) {
    // CORS headers for Flutter app
    const headers = {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
    };

    // Handle preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers });
    }

    // Return encrypted API key from environment variable
    return new Response(
      JSON.stringify({
        breezApiKey: env.BREEZ_API_KEY,
        version: '1.0.0',
        environment: 'production'
      }),
      { headers }
    );
  }
};
```

### 3. Add Environment Variable (Secret)

1. In Worker settings, go to **Settings** → **Variables**
2. Click **Add Variable** → **Encrypt**
3. Name: `BREEZ_API_KEY`
4. Value: `<YOUR_BREEZ_API_KEY_HERE>` (the base64-encoded certificate from Breez)
5. Click **Save and Deploy**

### 4. Get Worker URL

Your worker will be available at:
```
https://sabi-breez-config.sabibwallet.workers.dev
```

**Important:** Update `_configUrl` in `lib/config/breez_config.dart` with your actual Worker URL.

### 5. Test Worker

```bash
curl https://sabi-breez-config.sabibwallet.workers.dev
```

Expected response:
```json
{
  "breezApiKey": "MIIBczCCASWgAwIBAgIH...",
  "version": "1.0.0",
  "environment": "production"
}
```

## Security Best Practices

### ✅ Recommended

- ✅ Enable **Rate Limiting** in Cloudflare dashboard (100 req/min per IP)
- ✅ Add **Custom Domain** for your worker (optional but professional)
- ✅ Monitor Worker analytics for suspicious activity
- ✅ Rotate API key periodically (update in Worker env vars only)

### 🔒 Advanced (Optional)

Add request authentication to Worker:

```javascript
export default {
  async fetch(request, env) {
    // Verify request from your app
    const appToken = request.headers.get('X-App-Token');
    if (appToken !== env.APP_SECRET_TOKEN) {
      return new Response('Unauthorized', { status: 401 });
    }
    
    // ... rest of code
  }
};
```

Then in Flutter:
```dart
final res = await http.get(
  Uri.parse(_configUrl),
  headers: {'X-App-Token': 'your-secret-token'},
);
```

## Offline Behavior

The app handles offline scenarios gracefully:

1. **First Launch (Online)**: Fetches key from Cloudflare, caches in secure storage
2. **Subsequent Launches (Offline)**: Uses cached key from secure storage
3. **No Internet + No Cache**: Shows user-friendly error message

## Troubleshooting

### Error: "No Breez API key available"

**Cause**: App launched offline without cached key  
**Fix**: Connect to internet for first launch

### Error: "Cloudflare returned 500"

**Cause**: Worker deployment issue or missing environment variable  
**Fix**: 
1. Check Worker logs in Cloudflare dashboard
2. Verify `BREEZ_API_KEY` environment variable is set
3. Re-deploy worker

### Error: "Network error fetching API key"

**Cause**: DNS/connectivity issue  
**Fix**: App will automatically use cached key if available

## Cost

**Free Tier:**
- 100,000 requests/day
- 10ms CPU time per request
- Unlimited KV reads (for caching)

For Sabi Wallet with ~1,000 daily active users (each launches app 2-3 times):
- **Estimated Usage**: ~3,000 requests/day
- **Cost**: $0 (well within free tier)

## Monitoring

View Worker analytics:
1. Cloudflare Dashboard → **Workers & Pages**
2. Click your worker → **Metrics**
3. Monitor:
   - Request count
   - Error rate
   - CPU time
   - Geographic distribution

## Alternative: Cloudflare KV (Advanced)

For better caching and lower latency, use KV storage:

```javascript
export default {
  async fetch(request, env) {
    // Cache API key in KV for instant reads
    let apiKey = await env.BREEZ_CONFIG.get('api_key');
    
    if (!apiKey) {
      apiKey = env.BREEZ_API_KEY;
      await env.BREEZ_CONFIG.put('api_key', apiKey);
    }
    
    return new Response(JSON.stringify({ breezApiKey: apiKey }));
  }
};
```

Bind KV namespace in Worker settings.

---

**✅ Setup Complete!** Your Breez API key is now securely stored in Cloudflare's encrypted infrastructure, safe from version control and decompilation attacks.
