import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();

const db = admin.firestore();

/**
 * Accept workspace invite: user provides workspace ID (invite code).
 * Adds the current user to the workspace with the role set by the owner (inviteRole).
 */
export const acceptInvite = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Sign in to join a workspace.");
  }

  const workspaceId = typeof data?.workspaceId === "string" ? data.workspaceId.trim() : "";
  if (!workspaceId) {
    throw new functions.https.HttpsError("invalid-argument", "Invite code is required.");
  }

  const workspaceRef = db.collection("workspaces").doc(workspaceId);
  const workspaceSnap = await workspaceRef.get();
  if (!workspaceSnap.exists) {
    throw new functions.https.HttpsError("not-found", "Workspace not found. Check the invite code.");
  }

  const workspace = workspaceSnap.data()!;
  const ownerId = workspace.ownerId as string;
  const uid = context.auth.uid;

  if (ownerId === uid) {
    throw new functions.https.HttpsError("invalid-argument", "You already own this workspace.");
  }

  const members = { ...(workspace.members || {}) };
  if (members[uid]) {
    throw new functions.https.HttpsError("failed-precondition", "You are already a member of this workspace.");
  }

  if (!workspace.inviteEnabled) {
    throw new functions.https.HttpsError("failed-precondition", "This workspace is not accepting invites right now.");
  }

  const role = (workspace.inviteRole as string) || "viewer";
  if (role !== "editor" && role !== "viewer") {
    throw new functions.https.HttpsError("internal", "Invalid invite role.");
  }

  const token = context.auth.token as { name?: string; email?: string };
  const displayName = token.name || (token.email ? token.email.split("@")[0] : "") || "Member";

  const memberNames = { ...(workspace.memberNames || {}) };
  members[uid] = role;
  memberNames[uid] = displayName;

  await workspaceRef.update({
    members,
    memberNames,
    updatedAt: admin.firestore.Timestamp.now(),
  });

  return { success: true, message: "You have joined the workspace." };
});
