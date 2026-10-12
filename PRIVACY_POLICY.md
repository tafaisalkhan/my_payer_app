# Privacy Policy for My Namaz Scheduler (My Prayer App)

**Last Updated:** October 12, 2026

Welcome to **My Namaz Scheduler** ("we", "our", or "us"). We are committed to protecting your personal privacy. This Privacy Policy outlines our practices regarding data collection, usage, and disclosure when you use our mobile application.

---

## 1. Summary: Local-First & Privacy by Design

* **No Account Required:** You do not need to register, provide an email address, phone number, or create an account to use the app.
* **No Cloud Tracking or Analytics:** We do not track your activity, log your personal data, or sell your information to advertisers.
* **Offline-First:** All your prayer tracking records, task schedules, Quran recitation logs, and settings are stored locally on your device using SQLite and SharedPreferences.

---

## 2. Information We Access and How It Is Used

### A. Location Information (Coarse / Precise Location)
* **Purpose:** To calculate accurate Islamic prayer timings (Fajr, Dhuhr, Asr, Maghrib, Isha) and determine the exact Qibla direction towards the Holy Kaaba in Makkah.
* **Storage:** Your GPS coordinates (latitude and longitude) are processed locally on your device via astronomical calculation algorithms.
* **Sharing:** We **never** transmit, store, or sell your location data to any remote server or third-party entity.

### B. Device Sensors (Compass / Magnetometer)
* **Purpose:** To orient the Qibla Compass screen and guide you towards Makkah in real-time.
* **Storage:** Sensor data is read in real time and discarded immediately. It is never stored or transmitted.

### C. Audio and Media State
* **Purpose:** To play the Adhan (call to prayer) and schedule alarms when a prayer, Quran recitation, or scheduled work task begins.
* **Audio Focus:** The app requests standard audio focus during Adhan playback to pause background media (such as YouTube, Spotify, podcast players) and automatically resumes your media once the Adhan completes.
* **Volume Control:** Optional temporary volume boosting for prayer alarms so that you do not miss critical prayer calls. Volume levels are restored to your previous device settings after the alarm dismisses.

### D. Notifications and Exact Alarms (`SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM`)
* **Purpose:** Required by Android to trigger high-priority prayer Adhans, Quran recitation alerts, and task timeout reminders at the exact scheduled second, even when the device is locked or in Doze mode.
* **Storage:** Alarm timestamps are maintained entirely on your local device via Android's AlarmManager and local notifications.

---

## 3. Data Storage & Security

* **Local Database:** All task lists, focus sessions, prayer history, and custom settings remain encrypted and secured within your device's private app sandbox.
* **Data Deletion:** You can reset or permanently delete all local prayer records, Quran bookmarks, and scheduled tasks at any time directly inside **Settings > Data & Privacy > Clear Local Data**.
* **App Uninstallation:** Uninstalling the app permanently erases all locally stored databases and preferences from your device.

---

## 4. Third-Party Services & Libraries

Our application does not integrate third-party advertising SDKs, behavioral analytics (such as Facebook SDK, Google AdMob, or Firebase Analytics tracking), or tracking cookies.

We utilize open-source computational libraries:
* **Adhan Library:** Mathematical computation of Islamic prayer times based on solar coordinates.
* **Geolocator & Compass:** Direct device hardware access for position and magnetic heading.
* **Audioplayers & Native Android Audio Services:** Local audio playback for bundled Adhan and alarm tones.

---

## 5. Children's Privacy

Our application is designed for general audiences and families. We do not knowingly collect, store, or solicit personal data from children under the age of 13.

---

## 6. Permissions Summary

| Permission | Reason |
| :--- | :--- |
| `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION` | Calculate local prayer times and Qibla compass bearing |
| `POST_NOTIFICATIONS` | Deliver Adhan, Quran, and Task schedule notifications |
| `SCHEDULE_EXACT_ALARM` | Ensure alarms ring accurately at the exact prayer time |
| `WAKE_LOCK` | Allow device screen and alarm service to alert during prayer time |
| `FOREGROUND_SERVICE` / `FOREGROUND_SERVICE_MEDIA_PLAYBACK` | Reliable Adhan audio playback with media pause and resume |

---

## 7. Changes to This Privacy Policy

We may update our Privacy Policy periodically to reflect app updates or regulatory changes. Any updates will be reflected in this document and accessible through the app settings.

---

## 8. Contact Us

If you have questions, feedback, or inquiries regarding this Privacy Policy or the app, please open an issue on our GitHub repository:
- **Repository:** [https://github.com/tafaisalkhan/my_payer_app](https://github.com/tafaisalkhan/my_payer_app)
- **Email:** support@mynamazscheduler.app
