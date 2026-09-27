# App Review notes

---

No account or login is required.

PRIVACY: no data is collected. Everything is stored on the device in the app's Documents folder. Apart from Apple's map tiles and geocoder, no network requests. No account, analytics, advertising or third-party SDKs.

HOW TO USE: Tap the blue P in the middle of the tab bar (or "Park here") to save where the car is. The Park sheet pins the current location, lets the user set a meter (+15/+30/+1h/+2h or an end time), a garage level and spot, a photo and a note, then "Start the meter". The Meter tab shows the meter dial, the countdown and the "Leave by" time (meter end minus the walk back). Map shows the car, the distance and walking time, and hands off to Apple Maps for walking directions. Log keeps past spots. Rules holds street-cleaning reminders, saved garages, cars and settings.

LOCATION: when-in-use only, requested the first time the user parks. It is used to pin the car and to show the distance back. Nothing leaves the device (reverse geocoding for a street name uses Apple's system geocoder).
CAMERA: only when the user taps "Take photo" of the parking sign.
NOTIFICATIONS: requested the first time a meter is started; local notifications at the "leave by" time, 10 minutes before the meter ends, and when it ends; and weekly street-rule reminders the user creates.
LIVE ACTIVITY (Pro): the meter countdown on the Lock Screen and Dynamic Island, started when parking with a meter.

IN-APP PURCHASE: the app is free. There is one non-consumable purchase, Parked Pro (com.mattbusel.parked.pro). Free: one car, the spot, photo, meter, map and alerts, and the last 3 entries in the log. Pro: Lock Screen countdown, more cars, the full log, saved garages and street rules. To see the paywall: tap "Lock screen" next to a running meter, or Add under Street rules, Saved garages or Cars on the Rules tab, or See Pro on the Parked Pro card on the Rules tab. Restore purchase is on the paywall and that card.

2. PURPOSE AND TARGET AUDIENCE
Remember where the car is parked and avoid parking tickets. General audience of drivers; rated 4+.

3. SETUP AND ACCESS
No login or setup.

4. EXTERNAL SERVICES, TOOLS AND PLATFORMS
Apple MapKit (map tiles, reverse geocoding, Apple Maps hand-off). No analytics, advertising or third-party frameworks. SwiftUI, CoreLocation, ActivityKit/WidgetKit, UserNotifications, StoreKit 2.

5. REGIONAL DIFFERENCES
None. Distances in miles or kilometres follow the device region.

6. REGULATED INDUSTRY / PROTECTED MATERIAL
Not applicable. The app does not pay for parking. All art, text and code are my own work.
