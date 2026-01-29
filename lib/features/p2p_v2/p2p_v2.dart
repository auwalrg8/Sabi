/// P2P v2 Feature Module
/// 
/// Clean, unified P2P trading system built on NIP-99 Nostr protocol.
/// 
/// Architecture:
/// - Single StateNotifier provider for all P2P state
/// - Direct use of NostrP2POffer model (no conversion)
/// - Real-time trade communication via NIP-04 DMs
/// - Clean 4-screen UI (Home, Detail, Trade, Create)
library;

// Data models
export 'data/p2p_state.dart';

// Services
export 'services/p2p_nostr_service.dart';

// Providers
export 'providers/p2p_provider.dart';

// Screens
export 'screens/p2p_home_screen.dart';
export 'screens/p2p_offer_detail_screen.dart';
export 'screens/p2p_trade_screen.dart';
export 'screens/p2p_create_offer_screen.dart';

// Widgets
export 'widgets/offer_card.dart';
export 'widgets/trade_status_bar.dart';
