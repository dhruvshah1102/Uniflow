const admin = require('firebase-admin');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const logger = require('firebase-functions/logger');

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

const INVALID_TOKEN_CODES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
]);

const RETRYABLE_TOKEN_CODES = new Set([
  'messaging/internal-error',
  'messaging/server-unavailable',
  'messaging/unavailable',
]);

exports.onAssignmentCreated = onDocumentCreated('assignments/{assignmentId}', async (event) => {
  const assignment = event.data?.data();
  if (!assignment) return;

  const assignmentId = event.params.assignmentId;
  const mirroredNoticeSnap = await db
    .collection('notifications')
    .where('sourceId', '==', assignmentId)
    .limit(1)
    .get();
  if (!mirroredNoticeSnap.empty) {
    const mirroredNotice = mirroredNoticeSnap.docs[0].data() || {};
    if ((mirroredNotice.sourceCollection || '').toString() === 'assignments') return;
  }

  const courseId = (assignment.courseId || '').toString().trim();
  if (!courseId) return;

  const course = await getCourse(courseId);
  const recipients = await getCourseStudentIds(courseId);
  if (recipients.length === 0) return;

  const title = `New Assignment${course?.code ? `: ${course.code}` : ''}`;
  const body = course?.title
    ? `${course.title} has a new assignment${assignment.title ? ` - ${assignment.title}` : ''}`
    : assignment.title
      ? `New assignment uploaded: ${assignment.title}`
      : 'A new assignment has been uploaded.';

  await fanOutNotificationCopies(recipients, {
    title,
    body,
    type: 'assignment',
    courseId,
    route: '/student/dashboard?tab=tasks',
    sourceId: assignmentId,
    sourceCollection: 'assignments',
    payload: {
      assignmentId,
      courseId,
      title: assignment.title || '',
      description: assignment.description || '',
      dueDate: safeToString(assignment.dueDate),
    },
  });
});

exports.onNotificationCreated = onDocumentCreated('notifications/{notificationId}', async (event) => {
  const notification = event.data?.data();
  if (!notification) return;

  if (notification.deliveryCopy === true) return;

  const notificationId = event.params.notificationId;
  const targetUserId = (notification.userId || '').toString().trim();
  const audience = (notification.audience || '').toString().trim().toLowerCase();
  const courseId = (notification.courseId || '').toString().trim();
  const targetUserIds = Array.isArray(notification.targetUserIds)
    ? notification.targetUserIds.map((value) => value.toString().trim()).filter(Boolean)
    : [];
  const type = (notification.type || 'general').toString().trim().toLowerCase();
  const title = (notification.title || 'Uniflow').toString();
  const body = (notification.body || notification.message || '').toString();
  const baseData = {
    type,
    courseId,
    sourceId: (notification.sourceId || notificationId).toString(),
    notificationId,
    title,
    body,
  };

  if (targetUserId) {
    await sendPushToUsers([targetUserId], {
      title,
      body,
      data: {
        ...baseData,
        userId: targetUserId,
        route: (notification.route || '').toString(),
      },
    });
    return;
  }

  let recipients = targetUserIds;
  if (recipients.length === 0 && courseId) {
    recipients = await getCourseStudentIds(courseId);
  }
  if (recipients.length === 0 && audience === 'all') {
    recipients = await getAllActiveUserIds();
  }
  if (recipients.length === 0) return;

  await fanOutNotificationCopies(recipients, {
    title,
    body,
    type,
    courseId,
    route: (notification.route || '').toString(),
    sourceId: notificationId,
    sourceCollection: 'notifications',
    payload: {
      ...baseData,
      audience: audience || (courseId ? 'course' : 'users'),
      targetUserIds,
    },
  });
});

async function fanOutNotificationCopies(userIds, options) {
  const uniqueUserIds = [...new Set(userIds.filter(Boolean))];
  if (uniqueUserIds.length === 0) return;

  const payload = {
    title: options.title,
    body: options.body,
    type: options.type,
    courseId: options.courseId || '',
    route: options.route || '',
    sourceId: options.sourceId || '',
    sourceCollection: options.sourceCollection || '',
    ...options.payload,
  };

  const batch = db.batch();
  for (const userId of uniqueUserIds) {
    const doc = db.collection('notifications').doc();
    batch.set(doc, {
      userId,
      title: options.title,
      body: options.body,
      message: options.body,
      type: options.type,
      courseId: options.courseId || '',
      route: options.route || '',
      sourceId: options.sourceId || '',
      sourceCollection: options.sourceCollection || '',
      deliveryCopy: true,
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      ...payload,
    });
  }
  await batch.commit();

  await sendPushToUsers(uniqueUserIds, {
    title: options.title,
    body: options.body,
    data: {
      type: options.type,
      courseId: options.courseId || '',
      route: options.route || '',
      sourceId: options.sourceId || '',
      sourceCollection: options.sourceCollection || '',
    },
  });
}

async function sendPushToUsers(userIds, message) {
  const tokensByUser = await getTokensForUsers(userIds);
  const tokens = [...new Set(tokensByUser.flatMap((entry) => entry.tokens))];
  if (tokens.length === 0) {
    logger.info('No FCM tokens found for recipients', { userIds });
    return;
  }

  const retryableTokens = new Set();
  const failedTokens = new Set();

  for (const chunk of chunkArray(tokens, 500)) {
    const response = await messaging.sendEachForMulticast({
      notification: {
        title: message.title,
        body: message.body,
      },
      data: stringifyData(message.data || {}),
      tokens: chunk,
      android: {
        priority: 'high',
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
          },
        },
      },
    });

    response.responses.forEach((result, index) => {
      const token = chunk[index];
      if (result.success) return;
      const code = result.error?.code || '';
      if (INVALID_TOKEN_CODES.has(code)) {
        failedTokens.add(token);
      } else if (RETRYABLE_TOKEN_CODES.has(code)) {
        retryableTokens.add(token);
      } else {
        logger.warn('FCM send failed', { token, code, error: result.error?.message });
      }
    });
  }

  if (retryableTokens.size > 0) {
    const retryChunks = chunkArray([...retryableTokens], 500);
    for (const chunk of retryChunks) {
      const response = await messaging.sendEachForMulticast({
        notification: {
          title: message.title,
          body: message.body,
        },
        data: stringifyData(message.data || {}),
        tokens: chunk,
        android: {
          priority: 'high',
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
            },
          },
        },
      });

      response.responses.forEach((result, index) => {
        const token = chunk[index];
        if (result.success) return;
        const code = result.error?.code || '';
        if (INVALID_TOKEN_CODES.has(code)) {
          failedTokens.add(token);
        } else {
          logger.warn('FCM retry failed', { token, code, error: result.error?.message });
        }
      });
    }
  }

  if (failedTokens.size > 0) {
    await cleanupInvalidTokens([...failedTokens]);
  }
}

async function cleanupInvalidTokens(tokens) {
  const tokenSet = new Set(tokens.filter(Boolean));
  if (tokenSet.size === 0) return;

  const userSnap = await db.collection('users').get();
  const writes = [];
  for (const doc of userSnap.docs) {
    const data = doc.data() || {};
    const currentToken = (data.fcm_token || data.fcmToken || '').toString().trim();
    if (tokenSet.has(currentToken)) {
      writes.push(
        doc.ref.set(
          {
            fcm_token: '',
            fcmToken: '',
            fcm_token_updated_at: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true },
        ),
      );
    }

    const deviceTokensSnap = await doc.ref.collection('device_tokens').get();
    for (const tokenDoc of deviceTokensSnap.docs) {
      if (tokenSet.has(tokenDoc.id)) {
        writes.push(tokenDoc.ref.delete());
      }
    }
  }

  await Promise.all(writes);
}

async function getCourseStudentIds(courseId) {
  const enrollSnap = await db.collection('enrollments').where('courseId', '==', courseId).get();
  return enrollSnap.docs
    .map((doc) => (doc.data().studentId || '').toString().trim())
    .filter(Boolean);
}

async function getAllActiveUserIds() {
  const userSnap = await db.collection('users').get();
  return userSnap.docs
    .filter((doc) => {
      const role = (doc.data().role || '').toString().trim().toLowerCase();
      return role === 'student' || role === 'faculty' || role === 'admin';
    })
    .map((doc) => doc.id)
    .filter(Boolean);
}

async function getTokensForUsers(userIds) {
  const uniqueUserIds = [...new Set(userIds.filter(Boolean))];
  const entries = [];

  for (const userId of uniqueUserIds) {
    const userRef = db.collection('users').doc(userId);
    const userSnap = await userRef.get();
    const data = userSnap.data() || {};
    const tokens = new Set();

    const fieldTokens = [data.fcm_token, data.fcmToken].map((value) => (value || '').toString().trim()).filter(Boolean);
    fieldTokens.forEach((token) => tokens.add(token));

    const tokenDocs = await userRef.collection('device_tokens').get();
    tokenDocs.docs.forEach((doc) => tokens.add(doc.id));
    tokenDocs.docs.forEach((doc) => {
      const token = (doc.data().token || '').toString().trim();
      if (token) tokens.add(token);
    });

    entries.push({ userId, tokens: [...tokens] });
  }

  return entries;
}

async function getCourse(courseId) {
  const snap = await db.collection('courses').doc(courseId).get();
  if (!snap.exists) return null;
  return snap.data();
}

function stringifyData(data) {
  const output = {};
  Object.entries(data || {}).forEach(([key, value]) => {
    if (value === null || value === undefined) {
      output[key] = '';
      return;
    }
    if (Array.isArray(value)) {
      output[key] = JSON.stringify(value);
      return;
    }
    if (typeof value === 'object') {
      output[key] = JSON.stringify(value);
      return;
    }
    output[key] = String(value);
  });
  return output;
}

function chunkArray(values, size) {
  const chunks = [];
  for (let i = 0; i < values.length; i += size) {
    chunks.push(values.slice(i, i + size));
  }
  return chunks;
}

function safeToString(value) {
  if (value === null || value === undefined) return '';
  return String(value);
}
