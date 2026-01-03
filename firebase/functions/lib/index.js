"use strict";
/**
 * Sabi Wallet - Firebase Cloud Functions
 *
 * This module provides server-side push notifications for:
 * - Lightning payment received
 * - P2P trade events
 * - Zap notifications
 * - DM notifications
 * - VTU order updates
 *
 * Architecture:
 * 1. Devices register FCM tokens with their Nostr pubkey
 * 2. Webhooks/Nostr subscriptions trigger push notifications
 * 3. FCM sends notifications to registered devices
 */
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.sendTestNotification = exports.healthCheck = exports.cleanupStaleTokens = exports.vtuWebhook = exports.dmWebhook = exports.zapWebhook = exports.p2pTradeWebhook = exports.breezPaymentWebhook = exports.unregisterDevice = exports.registerDevice = void 0;
const admin = __importStar(require("firebase-admin"));
const functions = __importStar(require("firebase-functions"));
// Initialize Firebase Admin
admin.initializeApp();
// Firestore for device token storage
const db = admin.firestore();
const messaging = admin.messaging();
// ============================================================================
// DEVICE REGISTRATION ENDPOINTS
// ============================================================================
/**
 * Register a device for push notifications
 * Called from the Flutter app when user creates/restores wallet
 */
exports.registerDevice = functions.https.onRequest(async (req, res) => {
    // CORS headers
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type");
    if (req.method === "OPTIONS") {
        res.status(204).send("");
        return;
    }
    if (req.method !== "POST") {
        res.status(405).send("Method Not Allowed");
        return;
    }
    try {
        const { fcmToken, nostrPubkey, platform } = req.body;
        if (!fcmToken || !nostrPubkey) {
            res.status(400).json({ error: "Missing fcmToken or nostrPubkey" });
            return;
        }
        // Store device registration in Firestore
        const deviceRef = db.collection("devices").doc(fcmToken);
        await deviceRef.set({
            fcmToken,
            nostrPubkey,
            platform: platform || "android",
            registeredAt: admin.firestore.FieldValue.serverTimestamp(),
            lastActive: admin.firestore.FieldValue.serverTimestamp(),
        });
        // Also index by pubkey for quick lookup
        const pubkeyRef = db.collection("pubkey_devices").doc(nostrPubkey);
        await pubkeyRef.set({
            tokens: admin.firestore.FieldValue.arrayUnion(fcmToken),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
        functions.logger.info(`Device registered: ${nostrPubkey.substring(0, 8)}...`);
        res.status(200).json({ success: true, message: "Device registered" });
    }
    catch (error) {
        functions.logger.error("Error registering device:", error);
        res.status(500).json({ error: "Internal server error" });
    }
});
/**
 * Unregister a device (logout/delete account)
 */
exports.unregisterDevice = functions.https.onRequest(async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "POST, DELETE, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type");
    if (req.method === "OPTIONS") {
        res.status(204).send("");
        return;
    }
    try {
        const { fcmToken, nostrPubkey } = req.body;
        if (!fcmToken) {
            res.status(400).json({ error: "Missing fcmToken" });
            return;
        }
        // Remove device registration
        await db.collection("devices").doc(fcmToken).delete();
        // Remove from pubkey index
        if (nostrPubkey) {
            const pubkeyRef = db.collection("pubkey_devices").doc(nostrPubkey);
            await pubkeyRef.update({
                tokens: admin.firestore.FieldValue.arrayRemove(fcmToken),
            });
        }
        functions.logger.info(`Device unregistered: ${fcmToken.substring(0, 20)}...`);
        res.status(200).json({ success: true, message: "Device unregistered" });
    }
    catch (error) {
        functions.logger.error("Error unregistering device:", error);
        res.status(500).json({ error: "Internal server error" });
    }
});
// ============================================================================
// PUSH NOTIFICATION SENDERS
// ============================================================================
/**
 * Send push notification to a specific Nostr pubkey
 */
async function sendPushToUser(nostrPubkey, payload) {
    var _a;
    try {
        // Get all device tokens for this pubkey
        const pubkeyDoc = await db.collection("pubkey_devices").doc(nostrPubkey).get();
        if (!pubkeyDoc.exists) {
            functions.logger.info(`No devices registered for pubkey: ${nostrPubkey.substring(0, 8)}...`);
            return 0;
        }
        const tokens = ((_a = pubkeyDoc.data()) === null || _a === void 0 ? void 0 : _a.tokens) || [];
        if (tokens.length === 0) {
            return 0;
        }
        // Build FCM message
        const message = {
            tokens,
            notification: {
                title: payload.title,
                body: payload.body,
            },
            data: Object.assign({ type: payload.type }, payload.data),
            android: {
                priority: "high",
                notification: {
                    channelId: getChannelForType(payload.type),
                    priority: "high",
                    defaultSound: true,
                    defaultVibrateTimings: true,
                },
            },
            apns: {
                payload: {
                    aps: {
                        alert: {
                            title: payload.title,
                            body: payload.body,
                        },
                        sound: "default",
                        badge: 1,
                        contentAvailable: true,
                    },
                },
            },
        };
        // Send to all devices
        const response = await messaging.sendEachForMulticast(message);
        functions.logger.info(`Push sent to ${nostrPubkey.substring(0, 8)}...: ` +
            `${response.successCount} success, ${response.failureCount} failed`);
        // Clean up invalid tokens
        if (response.failureCount > 0) {
            const invalidTokens = [];
            response.responses.forEach((resp, idx) => {
                var _a;
                if (!resp.success && ((_a = resp.error) === null || _a === void 0 ? void 0 : _a.code) === "messaging/invalid-registration-token") {
                    invalidTokens.push(tokens[idx]);
                }
            });
            if (invalidTokens.length > 0) {
                await cleanupInvalidTokens(nostrPubkey, invalidTokens);
            }
        }
        return response.successCount;
    }
    catch (error) {
        functions.logger.error(`Error sending push to ${nostrPubkey}:`, error);
        return 0;
    }
}
/**
 * Remove invalid tokens from Firestore
 */
async function cleanupInvalidTokens(nostrPubkey, tokens) {
    try {
        // Remove from pubkey index
        const pubkeyRef = db.collection("pubkey_devices").doc(nostrPubkey);
        await pubkeyRef.update({
            tokens: admin.firestore.FieldValue.arrayRemove(...tokens),
        });
        // Remove device documents
        const batch = db.batch();
        tokens.forEach((token) => {
            batch.delete(db.collection("devices").doc(token));
        });
        await batch.commit();
        functions.logger.info(`Cleaned up ${tokens.length} invalid tokens`);
    }
    catch (error) {
        functions.logger.error("Error cleaning up tokens:", error);
    }
}
/**
 * Get Android notification channel for notification type
 */
function getChannelForType(type) {
    switch (type) {
        case "payment_received":
        case "payment_sent":
            return "sabi_wallet_payments";
        case "p2p_trade_started":
        case "p2p_payment_marked":
        case "p2p_payment_confirmed":
        case "p2p_funds_released":
        case "p2p_trade_cancelled":
        case "p2p_trade_disputed":
        case "p2p_new_message":
        case "p2p_new_inquiry":
            return "sabi_wallet_p2p";
        case "zap_received":
        case "dm_received":
            return "sabi_wallet_social";
        case "vtu_order_complete":
        case "vtu_order_failed":
            return "sabi_wallet_vtu";
        default:
            return "sabi_wallet_default";
    }
}
// ============================================================================
// WEBHOOK ENDPOINTS FOR EXTERNAL SERVICES
// ============================================================================
/**
 * Webhook for Breez SDK payment notifications
 * Configure Breez SDK to call this endpoint when payments arrive
 */
exports.breezPaymentWebhook = functions.https.onRequest(async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    if (req.method !== "POST") {
        res.status(405).send("Method Not Allowed");
        return;
    }
    try {
        const { nostrPubkey, amountSats, amountNaira, paymentHash, description, timestamp, } = req.body;
        if (!nostrPubkey) {
            res.status(400).json({ error: "Missing nostrPubkey" });
            return;
        }
        const formattedAmount = amountNaira
            ? `₦${Number(amountNaira).toLocaleString()}`
            : `${amountSats} sats`;
        await sendPushToUser(nostrPubkey, {
            title: "Payment Received ⚡",
            body: description || `You received ${formattedAmount}`,
            type: "payment_received",
            data: {
                amountSats: String(amountSats || "0"),
                amountNaira: String(amountNaira || "0"),
                paymentHash: paymentHash || "",
                timestamp: timestamp || new Date().toISOString(),
            },
        });
        res.status(200).json({ success: true });
    }
    catch (error) {
        functions.logger.error("Error in breezPaymentWebhook:", error);
        res.status(500).json({ error: "Internal server error" });
    }
});
/**
 * Webhook for P2P trade events
 * Called by P2P escrow service when trade state changes
 */
exports.p2pTradeWebhook = functions.https.onRequest(async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    if (req.method !== "POST") {
        res.status(405).send("Method Not Allowed");
        return;
    }
    try {
        const { nostrPubkey, tradeId, eventType, amount, counterpartyName, } = req.body;
        if (!nostrPubkey || !eventType) {
            res.status(400).json({ error: "Missing required fields" });
            return;
        }
        const notifications = {
            trade_started: {
                title: "P2P Trade Started 🔄",
                body: `${counterpartyName || "Someone"} started a trade with you`,
                type: "p2p_trade_started",
            },
            payment_marked: {
                title: "Payment Marked ✓",
                body: `Buyer marked payment as sent for ₦${amount}`,
                type: "p2p_payment_marked",
            },
            payment_confirmed: {
                title: "Payment Confirmed ✓",
                body: "Seller confirmed your payment",
                type: "p2p_payment_confirmed",
            },
            funds_released: {
                title: "Funds Released! 🎉",
                body: `₦${amount} trade completed successfully`,
                type: "p2p_funds_released",
            },
            trade_cancelled: {
                title: "Trade Cancelled",
                body: "Your P2P trade was cancelled",
                type: "p2p_trade_cancelled",
            },
            trade_disputed: {
                title: "Trade Disputed ⚠️",
                body: "A dispute has been raised on your trade",
                type: "p2p_trade_disputed",
            },
            new_message: {
                title: "New Trade Message 💬",
                body: `${counterpartyName || "Someone"} sent you a message`,
                type: "p2p_new_message",
            },
            new_inquiry: {
                title: "New Trade Inquiry 📩",
                body: `${counterpartyName || "Someone"} is interested in your offer`,
                type: "p2p_new_inquiry",
            },
        };
        const notification = notifications[eventType];
        if (!notification) {
            res.status(400).json({ error: `Unknown event type: ${eventType}` });
            return;
        }
        await sendPushToUser(nostrPubkey, Object.assign(Object.assign({}, notification), { data: {
                tradeId: tradeId || "",
                eventType,
            } }));
        res.status(200).json({ success: true });
    }
    catch (error) {
        functions.logger.error("Error in p2pTradeWebhook:", error);
        res.status(500).json({ error: "Internal server error" });
    }
});
/**
 * Webhook for Zap notifications
 */
exports.zapWebhook = functions.https.onRequest(async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    if (req.method !== "POST") {
        res.status(405).send("Method Not Allowed");
        return;
    }
    try {
        const { nostrPubkey, amountSats, senderName, senderPubkey, message, eventId, } = req.body;
        if (!nostrPubkey) {
            res.status(400).json({ error: "Missing nostrPubkey" });
            return;
        }
        const zapperName = senderName || (senderPubkey === null || senderPubkey === void 0 ? void 0 : senderPubkey.substring(0, 8)) || "Someone";
        await sendPushToUser(nostrPubkey, {
            title: "Zap Received ⚡",
            body: message
                ? `${zapperName} zapped you ${amountSats} sats: "${message}"`
                : `${zapperName} zapped you ${amountSats} sats!`,
            type: "zap_received",
            data: {
                amountSats: String(amountSats || 0),
                senderPubkey: senderPubkey || "",
                eventId: eventId || "",
            },
        });
        res.status(200).json({ success: true });
    }
    catch (error) {
        functions.logger.error("Error in zapWebhook:", error);
        res.status(500).json({ error: "Internal server error" });
    }
});
/**
 * Webhook for DM notifications
 */
exports.dmWebhook = functions.https.onRequest(async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    if (req.method !== "POST") {
        res.status(405).send("Method Not Allowed");
        return;
    }
    try {
        const { nostrPubkey, senderName, senderPubkey, preview, } = req.body;
        if (!nostrPubkey) {
            res.status(400).json({ error: "Missing nostrPubkey" });
            return;
        }
        const senderDisplay = senderName || (senderPubkey === null || senderPubkey === void 0 ? void 0 : senderPubkey.substring(0, 8)) || "Someone";
        await sendPushToUser(nostrPubkey, {
            title: `Message from ${senderDisplay}`,
            body: preview || "You have a new encrypted message",
            type: "dm_received",
            data: {
                senderPubkey: senderPubkey || "",
            },
        });
        res.status(200).json({ success: true });
    }
    catch (error) {
        functions.logger.error("Error in dmWebhook:", error);
        res.status(500).json({ error: "Internal server error" });
    }
});
/**
 * Webhook for VTU order updates
 */
exports.vtuWebhook = functions.https.onRequest(async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    if (req.method !== "POST") {
        res.status(405).send("Method Not Allowed");
        return;
    }
    try {
        const { nostrPubkey, orderId, orderType, // "airtime" | "data" | "electricity"
        status, // "complete" | "failed"
        amount, phoneNumber, } = req.body;
        if (!nostrPubkey || !status) {
            res.status(400).json({ error: "Missing required fields" });
            return;
        }
        const orderTypeDisplay = orderType === "airtime" ? "Airtime"
            : orderType === "data" ? "Data"
                : orderType === "electricity" ? "Electricity"
                    : "VTU";
        const isSuccess = status === "complete";
        await sendPushToUser(nostrPubkey, {
            title: isSuccess
                ? `${orderTypeDisplay} Purchase Successful ✓`
                : `${orderTypeDisplay} Purchase Failed ✗`,
            body: isSuccess
                ? `₦${amount} ${orderTypeDisplay.toLowerCase()} sent to ${phoneNumber}`
                : `Your ${orderTypeDisplay.toLowerCase()} purchase could not be processed`,
            type: isSuccess ? "vtu_order_complete" : "vtu_order_failed",
            data: {
                orderId: orderId || "",
                orderType: orderType || "",
                status,
            },
        });
        res.status(200).json({ success: true });
    }
    catch (error) {
        functions.logger.error("Error in vtuWebhook:", error);
        res.status(500).json({ error: "Internal server error" });
    }
});
// ============================================================================
// SCHEDULED FUNCTIONS
// ============================================================================
/**
 * Clean up stale device tokens (devices that haven't been active in 30 days)
 * Runs daily at 2:00 AM
 */
exports.cleanupStaleTokens = functions.pubsub
    .schedule("0 2 * * *")
    .timeZone("Africa/Lagos")
    .onRun(async () => {
    try {
        const thirtyDaysAgo = admin.firestore.Timestamp.fromDate(new Date(Date.now() - 30 * 24 * 60 * 60 * 1000));
        const staleDevices = await db.collection("devices")
            .where("lastActive", "<", thirtyDaysAgo)
            .get();
        if (staleDevices.empty) {
            functions.logger.info("No stale devices to clean up");
            return null;
        }
        const batch = db.batch();
        const tokensToRemove = [];
        staleDevices.docs.forEach((doc) => {
            const data = doc.data();
            batch.delete(doc.ref);
            tokensToRemove.push({ pubkey: data.nostrPubkey, token: data.fcmToken });
        });
        await batch.commit();
        // Remove from pubkey indexes
        for (const { pubkey, token } of tokensToRemove) {
            await db.collection("pubkey_devices").doc(pubkey).update({
                tokens: admin.firestore.FieldValue.arrayRemove(token),
            }).catch(() => { });
        }
        functions.logger.info(`Cleaned up ${staleDevices.size} stale device tokens`);
        return null;
    }
    catch (error) {
        functions.logger.error("Error cleaning up stale tokens:", error);
        return null;
    }
});
// ============================================================================
// UTILITY ENDPOINTS
// ============================================================================
/**
 * Health check endpoint
 */
exports.healthCheck = functions.https.onRequest((req, res) => {
    res.status(200).json({
        status: "healthy",
        timestamp: new Date().toISOString(),
        version: "1.0.0",
    });
});
/**
 * Send a test notification (for debugging)
 */
exports.sendTestNotification = functions.https.onRequest(async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    if (req.method !== "POST") {
        res.status(405).send("Method Not Allowed");
        return;
    }
    try {
        const { nostrPubkey, title, body, type } = req.body;
        if (!nostrPubkey) {
            res.status(400).json({ error: "Missing nostrPubkey" });
            return;
        }
        const count = await sendPushToUser(nostrPubkey, {
            title: title || "Test Notification 🧪",
            body: body || "This is a test push notification from Sabi Wallet",
            type: type || "general",
        });
        res.status(200).json({
            success: true,
            message: `Sent to ${count} device(s)`
        });
    }
    catch (error) {
        functions.logger.error("Error sending test notification:", error);
        res.status(500).json({ error: "Internal server error" });
    }
});
//# sourceMappingURL=index.js.map