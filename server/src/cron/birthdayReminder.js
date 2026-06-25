/**
 * Birthday Reminder Cron Job
 * Runs daily to check for user birthdays and notify friends
 */
const cron = require('node-cron');
const { User } = require('../db/mongo');
const { Message } = require('../db/message');
const { sendPushNotification } = require('../firebase');

/**
 * Check if today is the user's birthday
 */
function isBirthdayToday(birthday) {
  if (!birthday) return false;
  
  const today = new Date();
  const bday = new Date(birthday);
  
  return today.getMonth() === bday.getMonth() && 
         today.getDate() === bday.getDate();
}

/**
 * Get friends of a user (users who have exchanged messages)
 * For simplicity, we'll notify all users who have the birthday person in their contacts
 * In a real app, you might want to track actual friendships
 */
async function getUserFriends(userId) {
  // Find users who have exchanged messages with this person
  const sentTo = await Message.distinct('to', { from: userId });
  const receivedFrom = await Message.distinct('from', { to: userId });
  const allContactIds = [...new Set([...sentTo, ...receivedFrom])];

  if (allContactIds.length === 0) return [];

  return await User.find({
    userId: { $in: allContactIds },
    fcmToken: { $exists: true, $ne: null }
  }).select('userId username fcmToken');
}

/**
 * Send birthday notifications to friends
 */
async function sendBirthdayNotifications() {
  console.log('🎂 Checking for birthdays...');
  
  try {
    // Find all users with birthdays today
    const usersWithBday = await User.find({ 
      bday: { $exists: true, $ne: null }
    });
    
    const birthdayPeople = usersWithBday.filter(u => isBirthdayToday(u.bday));
    
    if (birthdayPeople.length === 0) {
      console.log('🎂 No birthdays today');
      return;
    }
    
    console.log(`🎂 Found ${birthdayPeople.length} birthday(s) today`);
    
    for (const birthdayPerson of birthdayPeople) {
      const friends = await getUserFriends(birthdayPerson.userId);
      
      console.log(`🎂 Sending birthday notifications for ${birthdayPerson.username} to ${friends.length} friends`);
      
      for (const friend of friends) {
        try {
          await sendPushNotification(friend.fcmToken, {
            title: `🎉 It's ${birthdayPerson.username}'s Birthday!`,
            body: `Wish them a happy birthday in SecureChat!`,
            data: {
              type: 'birthday_reminder',
              birthdayPersonId: birthdayPerson.userId,
              birthdayPersonName: birthdayPerson.username,
            },
          });
        } catch (error) {
          console.error(`Failed to send birthday notification to ${friend.username}:`, error.message);
        }
      }
    }
    
    console.log('🎂 Birthday notifications sent successfully');
  } catch (error) {
    console.error('❌ Error in birthday reminder cron:', error);
  }
}

/**
 * Start the birthday reminder cron job
 * Runs every day at 9:00 AM
 */
function startBirthdayReminderCron() {
  // Schedule: 0 9 * * * = At 09:00 every day
  cron.schedule('0 9 * * *', sendBirthdayNotifications, {
    scheduled: true,
    timezone: 'UTC'
  });
  
  console.log('🎂 Birthday reminder cron scheduled (daily at 9:00 AM UTC)');
  
  // Also run immediately on startup for testing (remove in production)
  // sendBirthdayNotifications();
}

module.exports = {
  startBirthdayReminderCron,
  sendBirthdayNotifications,
};
