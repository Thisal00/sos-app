const functions = require("firebase-functions");
const admin = require("firebase-admin");

// Firebase Admin එක Initialize කරනවා
admin.initializeApp();

// ============================================================================
// 💬 1. CHAT NOTIFICATIONS (අලුත් මැසේජ් එකක් ආවම යවන එක)
// ============================================================================
exports.sendChatNotification = functions.firestore
  .document("families/{familyCode}/messages/{messageId}")
  .onCreate(async (snap, context) => {
    const messageData = snap.data();
    const senderName = messageData.senderName || "Family Member";
    const text = messageData.text;
    const familyCode = context.params.familyCode;

    // පවුලේ ඉන්න අනිත් හැමෝගෙම (ෆැමිලි කෝඩ් එක සමාන අයගේ) ඩේටා ගන්නවා
    const usersSnapshot = await admin.firestore().collection("users")
      .where("familyCode", "==", familyCode).get();

    const tokens = [];
    
    usersSnapshot.forEach((doc) => {
      const user = doc.data();
      // මැසේජ් එක යවපු කෙනාටම ආයේ නොටිෆිකේෂන් යවන්නේ නෑ, අනිත් අයට විතරයි යවන්නේ
      if (user.fcmToken && doc.id !== messageData.senderId) {
        tokens.push(user.fcmToken);
      }
    });

    if (tokens.length > 0) {
      const payload = {
        notification: {
          title: `💬 New message from ${senderName}`,
          body: text ? text : "Sent a photo or attachment 📷",
        },
        data: {
          click_action: "FLUTTER_NOTIFICATION_CLICK", // ඇප් එක ඕපන් වෙන්න
          screen: "chat",
        }
      };
      
      // අනිත් හැමෝටම මැසේජ් එක Push කරනවා!
      console.log(`Sending chat notification to ${tokens.length} devices.`);
      return admin.messaging().sendToDevice(tokens, payload);
    }
    return null;
  });

// ============================================================================
// 🚨 2. SOS NOTIFICATIONS (කවුරුහරි අනතුරක වැටිලා SOS එබුවම යවන එක)
// ============================================================================
exports.sendSOSNotification = functions.firestore
  .document("users/{userId}")
  .onUpdate(async (change, context) => {
    const newData = change.after.data();
    const oldData = change.before.data();

    // කවුරුහරි අලුතින් SOS එක "True" කළොත් විතරක් මේක වැඩ කරනවා!
    if (newData.isSOS === true && oldData.isSOS !== true) {
      const familyCode = newData.familyCode;
      
      if (!familyCode) return null;

      const usersSnapshot = await admin.firestore().collection("users")
        .where("familyCode", "==", familyCode).get();

      const tokens = [];
      usersSnapshot.forEach((doc) => {
        // SOS එබුව කෙනාට ඇරෙන්න අනිත් අයට Notification එක යවනවා
        if (doc.data().fcmToken && doc.id !== context.params.userId) {
          tokens.push(doc.data().fcmToken);
        }
      });

      if (tokens.length > 0) {
        const payload = {
          notification: {
            title: "🚨 EMERGENCY SOS!",
            body: `${newData.name || 'A family member'} is in danger! Open the app immediately to track their location.`,
          },
          data: { 
            click_action: "FLUTTER_NOTIFICATION_CLICK",
            screen: "sos"
          }
        };
        
        console.log(`Sending SOS notification to ${tokens.length} devices.`);
        return admin.messaging().sendToDevice(tokens, payload);
      }
    }
    return null;
  });