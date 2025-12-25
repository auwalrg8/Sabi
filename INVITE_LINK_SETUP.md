# Invite Link Setup for sabiwallet.online

This document describes how to set up the invite link redemption landing page on sabiwallet.online.

## Overview

When a user invites a friend to become a recovery guardian, an invite link is generated in the format:
```
https://sabiwallet.online/invite?code=<INVITE_CODE>&from=<INVITER_NPUB>
```

The landing page needs to:
1. Display the invitation details
2. Help the user set up a Nostr account (generate keys)
3. Guide them to install the Sabi Wallet app
4. Deep link into the app with the invitation context

## Domain Setup

### DNS Configuration
Ensure the domain `sabiwallet.online` is pointing to your hosting provider:
- Add an A record pointing to your server IP
- Or use a CNAME for Cloudflare/Vercel/Netlify

### SSL Certificate
Ensure HTTPS is enabled (Let's Encrypt or Cloudflare)

## Landing Page Requirements

### Required Parameters
The invite URL will include:
- `code` - Unique invite code (temporary Nostr npub)
- `from` - The inviter's npub (for display purposes)

### Page Flow

#### Step 1: Welcome Screen
```html
<h1>You've been invited to be a Recovery Guardian!</h1>
<p>[Inviter Name] wants you to help protect their Sabi Wallet.</p>
<p>As a guardian, you'll hold a small piece of their wallet backup 
   that they can use to recover their funds if they lose their phone.</p>
```

#### Step 2: Nostr Account Setup
For users who don't have Nostr:
```html
<h2>Let's create your Nostr account</h2>
<p>Nostr is a decentralized social network. Your account is just a 
   cryptographic key pair - no email or password needed!</p>
<button>Generate My Nostr Keys</button>
```

Generate keys using JavaScript:
```javascript
import { generateSecretKey, getPublicKey, nip19 } from 'nostr-tools';

const sk = generateSecretKey(); // Uint8Array
const pk = getPublicKey(sk);    // hex string
const nsec = nip19.nsecEncode(sk);
const npub = nip19.npubEncode(pk);

// Store securely and display to user
localStorage.setItem('nostr_nsec', nsec);
```

#### Step 3: App Install Prompt
```html
<h2>Download Sabi Wallet</h2>
<p>Install the app to complete the guardian setup.</p>
<a href="https://play.google.com/store/apps/details?id=com.sabi.wallet">
  <img src="play-store-badge.png" alt="Get it on Google Play">
</a>
<a href="https://apps.apple.com/app/sabi-wallet/id...">
  <img src="app-store-badge.png" alt="Download on App Store">
</a>
```

#### Step 4: Deep Link
After app install, redirect to app:
```javascript
// Try to open the app with the invite context
const deepLink = `sabiwallet://invite?code=${inviteCode}&nsec=${generatedNsec}`;
window.location.href = deepLink;

// Fallback to app store if not installed
setTimeout(() => {
  window.location.href = 'https://play.google.com/store/apps/details?id=com.sabi.wallet';
}, 2000);
```

## Cloudflare Worker Implementation

If using Cloudflare Workers:

```javascript
// worker.js
export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    
    if (url.pathname.startsWith('/invite')) {
      const code = url.searchParams.get('code');
      const from = url.searchParams.get('from');
      
      // Return the invite landing page HTML
      return new Response(generateInvitePage(code, from), {
        headers: { 'content-type': 'text/html' },
      });
    }
    
    // Default: redirect to main site
    return Response.redirect('https://sabiwallet.online', 301);
  }
};

function generateInvitePage(code, from) {
  return `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Recovery Guardian Invite - Sabi Wallet</title>
  <style>
    body {
      font-family: 'Inter', sans-serif;
      background: #0C0C1A;
      color: white;
      margin: 0;
      padding: 20px;
      min-height: 100vh;
    }
    .container { max-width: 400px; margin: 0 auto; }
    h1 { color: #F7931A; }
    .btn {
      background: #F7931A;
      color: #0C0C1A;
      padding: 16px 32px;
      border: none;
      border-radius: 12px;
      font-size: 16px;
      font-weight: 600;
      cursor: pointer;
      width: 100%;
      margin: 10px 0;
    }
    .btn-outline {
      background: transparent;
      border: 2px solid #F7931A;
      color: #F7931A;
    }
  </style>
</head>
<body>
  <div class="container">
    <h1>🛡️ Guardian Invite</h1>
    <p>You've been invited to be a recovery guardian for a Sabi Wallet user.</p>
    
    <div id="step1">
      <h2>What is a Recovery Guardian?</h2>
      <p>As a guardian, you'll securely hold a small piece of backup data. 
         If your friend loses their phone, they can contact you to help 
         recover their wallet.</p>
      <button class="btn" onclick="showStep2()">I'll Help!</button>
    </div>
    
    <div id="step2" style="display:none;">
      <h2>Download Sabi Wallet</h2>
      <p>Install the app to accept the guardian invite.</p>
      <a href="sabiwallet://invite?code=${code}" class="btn" style="display:block;text-align:center;text-decoration:none;">
        Open in App
      </a>
      <a href="https://play.google.com/store/apps/details?id=com.sabi.wallet" 
         class="btn btn-outline" style="display:block;text-align:center;text-decoration:none;">
        Download for Android
      </a>
    </div>
  </div>
  
  <script>
    function showStep2() {
      document.getElementById('step1').style.display = 'none';
      document.getElementById('step2').style.display = 'block';
    }
  </script>
</body>
</html>
  `;
}
```

## App-Side Handling

In the Flutter app, handle the deep link in `main.dart`:

```dart
// Handle sabiwallet://invite?code=xxx&nsec=xxx
void handleDeepLink(Uri uri) {
  if (uri.scheme == 'sabiwallet' && uri.host == 'invite') {
    final code = uri.queryParameters['code'];
    final nsec = uri.queryParameters['nsec'];
    
    // Navigate to guardian acceptance screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AcceptGuardianInviteScreen(
          inviteCode: code,
          nsec: nsec,
        ),
      ),
    );
  }
}
```

## Security Considerations

1. **Invite Code Expiration**: Invite codes should expire after 7 days
2. **Single Use**: Each invite code can only be used once
3. **Rate Limiting**: Limit invite generation to prevent abuse
4. **HTTPS Only**: All communication must be over HTTPS
5. **Key Security**: Never transmit nsec keys in URLs in production - use a more secure handoff method

## Testing

1. Generate an invite link in the app
2. Open the link in a browser
3. Verify the landing page displays correctly
4. Test the deep link flow
5. Verify the app handles the invite correctly

## Next Steps

- [ ] Deploy landing page to sabiwallet.online
- [ ] Set up DNS and SSL
- [ ] Configure deep link handling in Android/iOS
- [ ] Add analytics tracking
- [ ] Create invite expiration cleanup job
