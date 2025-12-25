# Social Recovery Feature Documentation

## Overview

Sabi Wallet implements a Social Recovery feature that allows users to recover their wallet by contacting trusted friends (guardians) instead of storing a seed phrase. This uses Shamir's Secret Sharing scheme to split the wallet seed into multiple shares, where any 3 of 5 shares can reconstruct the original seed.

## How It Works

### Shamir's Secret Sharing (3-of-5)

The wallet seed is split into 5 shares using Shamir's Secret Sharing algorithm:
- Each guardian receives 1 share
- Any 3 shares can reconstruct the original seed
- 2 or fewer shares reveal nothing about the seed

This provides:
- **Redundancy**: Up to 2 guardians can be unavailable
- **Security**: Collusion of 2 guardians cannot compromise the wallet
- **Flexibility**: User can replace guardians over time

### P2P Communication via Nostr

All communication happens via Nostr encrypted DMs (NIP-04):
- No central server required
- End-to-end encrypted
- Decentralized and censorship-resistant

## User Flows

### 1. Setting Up Social Recovery

**Location**: Backup & Recovery Screen → Social Recovery

1. User selects "Pick 3 trusted guys" backup option
2. User picks 3-5 contacts from:
   - Nostr follows (recommended - already have npub)
   - Device contacts (need to invite to Nostr first)
3. For each guardian:
   - If on Nostr: Share sent via encrypted DM
   - If not on Nostr: SMS/WhatsApp invite link sent
4. Shares distributed to all guardians
5. Recovery setup marked as complete

**Files Involved**:
- `lib/features/onboarding/presentation/screens/backup_choice_screen.dart`
- `lib/features/recovery/contact_picker_screen.dart`
- `lib/features/onboarding/presentation/screens/social_recovery_screen.dart`
- `lib/features/recovery/social_recovery_service.dart`

### 2. Managing Guardians

**Location**: Profile → Backup & Recovery → Manage Guardians

Users can:
- **View guardians**: See all guardians with health status
- **Add guardian**: Add new guardian (max 5)
- **Remove guardian**: Remove guardian (min 3)
- **Replace guardian**: Swap one guardian for another
- **Ping guardians**: Check if guardians are online

**Health Status Indicators**:
- 🟢 **Healthy**: Seen on Nostr in last 24 hours
- 🟡 **Warning**: Seen in last 7 days
- 🔴 **Offline**: Not seen in 7+ days
- ⚪ **Unknown**: Never checked

**Files Involved**:
- `lib/features/profile/presentation/screens/backup_recovery_screen.dart`
- `lib/features/recovery/guardian_management_screen.dart`

### 3. Recovering Wallet

**Location**: Onboarding → Recover Wallet → Social Recovery

1. User enters their Nostr npub or phone number
2. App looks up their recovery contacts
3. Recovery requests sent to all guardians via Nostr DM
4. Guardians open the DM and share their piece
5. Once 3+ shares received, wallet is reconstructed
6. User regains access to their funds

**Files Involved**:
- `lib/features/onboarding/presentation/screens/recover_with_guys_screen.dart`

## Technical Implementation

### RecoveryContact Model

```dart
class RecoveryContact {
  final String name;
  final String npub;
  final String? phoneNumber;
  final int shareIndex;          // Which share this guardian holds (1-5)
  final bool shareDelivered;     // Has the share been sent successfully
  final DateTime? shareDeliveredAt;
  final DateTime? lastSeen;      // Last Nostr activity
  final bool isOnNostr;
  
  GuardianHealthStatus get healthStatus {
    if (lastSeen == null) return GuardianHealthStatus.unknown;
    final now = DateTime.now();
    final diff = now.difference(lastSeen!);
    if (diff.inHours < 24) return GuardianHealthStatus.healthy;
    if (diff.inDays < 7) return GuardianHealthStatus.warning;
    return GuardianHealthStatus.offline;
  }
}
```

### Key Service Methods

**SocialRecoveryService**:
```dart
// Split seed into shares
static List<String> splitSeedIntoShares(String seedPhrase);

// Reconstruct seed from shares
static String reconstructSeedFromShares(List<String> shares);

// Send shares to guardians
static Future<void> sendRecoverySharesWithTracking(List<RecoveryContact> contacts);

// Request shares for recovery
static Future<void> requestRecoveryShares();

// Listen for incoming shares
static Stream<RecoveryShare> listenForRecoveryShares();

// Attempt recovery with collected shares
static Future<String?> attemptRecovery(List<RecoveryShare> shares);

// Guardian management
static Future<void> addGuardian(RecoveryContact guardian);
static Future<void> removeGuardian(String npub);
static Future<void> replaceGuardian(String oldNpub, RecoveryContact newGuardian);

// Health checks
static Future<List<RecoveryContact>> pingGuardians();
static Future<Map<String, dynamic>> getRecoveryHealth();
```

### Nostr Message Formats

**Recovery Share (sent to guardian)**:
```json
{
  "type": "sabi_recovery_share",
  "version": 1,
  "share_index": 1,
  "share_data": "<encrypted_share>",
  "timestamp": 1703462400,
  "message": "You are now a recovery guardian for [User]'s Sabi Wallet."
}
```

**Recovery Request (sent during recovery)**:
```json
{
  "type": "sabi_recovery_request",
  "version": 1,
  "timestamp": 1703462400,
  "message": "I need to recover my Sabi Wallet. Please send me the recovery share I gave you."
}
```

**Recovery Response (guardian returns share)**:
```json
{
  "type": "sabi_recovery_share",
  "version": 1,
  "share_index": 1,
  "share_data": "<encrypted_share>",
  "timestamp": 1703462400
}
```

## Storage

### Local Storage (Hive)
- `recovery_contacts` - List of guardian contacts with metadata
- `social_recovery_setup` - Boolean flag if recovery is configured

### Secure Storage
- Wallet seed (before splitting)
- Nostr private key

## Home Screen Integration

A suggestion banner appears on the home screen when:
1. User has backed up with seed phrase but not social recovery
2. User has a wallet but no backup configured

**Location**: Suggestions slider on home screen

## Security Considerations

1. **Share Distribution**: Shares are sent via NIP-04 encrypted DMs
2. **No Server**: All data is stored locally or on Nostr relays
3. **Threshold**: 3-of-5 prevents single point of failure
4. **Guardian Verification**: Only Nostr users with verified npubs can be guardians
5. **Health Monitoring**: Regular checks ensure guardians are still accessible

## Testing

### Manual Testing Checklist

- [ ] Create new wallet with social recovery
- [ ] Select guardians from Nostr follows
- [ ] Invite phone contact to Nostr
- [ ] Verify shares are sent via DM
- [ ] Check guardian health status updates
- [ ] Add new guardian
- [ ] Remove guardian
- [ ] Replace guardian
- [ ] Perform wallet recovery
- [ ] Verify recovered wallet matches original

### Test Accounts

For testing, use test Nostr accounts on relay `wss://relay.damus.io`:
- Test Guardian 1: npub1test...
- Test Guardian 2: npub1test...
- Test Guardian 3: npub1test...

## Future Enhancements

1. **Time-locked Recovery**: Add delay before recovery completes
2. **Guardian Notifications**: Push notifications when recovery requested
3. **Multi-sig Integration**: Combine with hardware wallet
4. **Guardian Rewards**: Incentive system for active guardians
5. **Cross-app Compatibility**: Standard protocol for other wallets

## Files Changed

### New Files
- `lib/features/recovery/guardian_management_screen.dart`

### Modified Files
- `lib/features/recovery/social_recovery_service.dart`
- `lib/features/recovery/contact_picker_screen.dart`
- `lib/features/nostr/nostr_service.dart`
- `lib/features/profile/presentation/screens/backup_recovery_screen.dart`
- `lib/features/onboarding/presentation/screens/recover_with_guys_screen.dart`
- `lib/features/onboarding/presentation/screens/backup_choice_screen.dart`
- `lib/features/home/providers/suggestions_provider.dart`
- `lib/features/home/widgets/suggestions_slider.dart`
- `lib/features/wallet/presentation/screens/home_screen.dart`

## Troubleshooting

### "No recovery contacts found"
- Check if user has set up social recovery
- Verify contacts are stored in Hive

### "Share not delivered"
- Check Nostr connection
- Verify guardian's npub is correct
- Try resending share

### "Recovery timeout"
- Guardians may be offline
- Check relay connectivity
- Try again later

### "Failed to reconstruct wallet"
- Need at least 3 valid shares
- Shares may be corrupted
- Contact support
