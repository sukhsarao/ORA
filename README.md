# ORA - ORA is a modern SwiftUI iOS 17 app built for Melbourne cafe lovers.

- BY Sukhman Singh and Sruthy Ramesh

## App Overview

ORA is an interactive cafe discovery app that makes exploring Melbourne’s cafe culture feel personal, playful, and beautifully designed.

The journey begins with a welcoming launch screen that guides users to sign up or log in. Once signed in, you’re taken to the Home feed, which showcases curated ORA cafes near you in a swipeable card deck swipe right to like, swipe left to skip. Every cafe you like is automatically saved to your Saved Cafes tab, so your favourites are always easy to revisit.

Each cafe card is dynamic tap it and the image transitions between photos, revealing details like amenities, menu highlights, address, and distance from your location. You can even view the cafe’s specials or browse the recents section, where people share photos from their latest visits.

In the Saved tab, you’ll find every cafe you’ve liked, with a drag-and-drop interface for easy organisation. You can delete items simply by dragging them to the trash, or create custom folders like Study Dates or Weekend Brunch to sort cafes into meaningful groups. Inside each folder, you can rearrange items, sort A–Z or Z–A, and toggle between grid or list view for your preferred layout...

The Map view brings all your discoveries together. Tapping a cafe’s pin adds a red pin showing your saved spots, while blue pins highlight trending cafes based on the most right-swiped locations nearby helping you find what’s popular around you at a glance.

On the Search page, you can explore menu items directly. The smart search bar offers visual shortcuts with images (for example, tapping Hot Chocolate instantly shows every cafe serving it). From these results, you can jump straight to a cafe page and tap the heart icon to save or unsave it.

The Profile view celebrates your personal story in ORA. It displays your statistics (Memories, Pins, and Favourites), lets you edit your username or profile image, and even create Memories posts where you can add a caption, tag a cafe, and choose whether to keep it private or make it public (so others can see it under that cafe’s recent section).

Finally, the Settings menu at the top of the header lets you switch between Light and Dark mode or log out with a single tap.

## Our Goal:

To combine elegant UX, robust architecture, and meaningful data persistence into a seamless, professional iOS experience that blends exploration with memory making every cafe visit feel personal. ☕✨

## Tech Details

- Language: SwiftUI iOS 17
- Persistence: SwiftData (local) + Firebase Firestore (cloud)
- API: Google Places API + Unsplash REST API
- Auth: Firebase Auth (email + username login)
- Architecture: MVVM
- Testing: XCTest
- Docs: DocC

## Data Persistence (SwiftData + Firebase)

- SwiftData (Local Storage)
  _ SwiftData is used for features that improve performance and personalization on the device such as storing the user’s Saved Cafe Folders and their most recent searches.
  _ Folders act purely as a local organizational layer, allowing users to group cafes (e.g., “Study Spots”, “Brunch with Friends”) without altering the actual cloud data.
  _ Then a cafe is added to or removed from a folder, the operation only affects the folder view it doesn’t delete or modify the cafe in Firebase.
  _ Similarly, removing a cafe from “Saved” does not remove it from any folders, keeping them logically independent. \* This approach ensures folders remain as a flexible way for users to organize their favourites.

- Firebase Firestore (Cloud Storage)
  _ Firebase stores all core, shared, and user generated data so it remains accessible across devices and sessions.
  _ Specifically, we use Firestore for:
  _ User authentication and profile data (via Firebase Auth)
  _ Cafes and menu collections: structured as separate documents because menus can grow large and update frequently \* Memories stored separately from users for scalability, since each user can attach multiple photos, captions, and visibility options
  This design keeps the app both responsive offline (via SwiftData) and consistent online (via Firebase), ensuring users always have access to their data even when switching devices or going offline.

## API Key

- Get API keys:
  - Google Places: create a key in Google Cloud Console; enable Places API.(Free Credits)
  - Unsplash: create a developer account. grab an Access Key.(Free API)
- Add them to Secrets (plist) before building:
  - GOOGLE_PLACES_API_KEY = "<YOUR_GOOGLE_KEY>"
  - UNSPLASH_ACCESS_KEY = "<YOUR_UNSPLASH_KEY>"
- Build & run.

### Google Places API (context + implementation)

- Why it fits: ORA’s cards show address, rating, distance, and a few photos. Places gives us authoritative data that complements our Firebase cafe records.
- Where used in the app:
  - CafePageView calls a PlacesManager to enrich a cafe with:
    - formatted_address
    - rating
    - geometry.location (lat/lng → used for distance)
    - photo references (turned into image URLs)
  - Map view: pins and distances rely on those coordinates.

### Unsplash API (context + implementation)

- Why it fits: We want visually rich surfaces. If a café lacks images, Unsplash’s curated photography fills gaps (e.g., “Latte”, “Mocha” shortcuts).
- Where used in the app:
  - UnsplashClient (an actor) provides:
    - url(for term:) -> returns a single small/thumbnail image URL for a keyword
    - prefetch(\_:) -> fetch multiple terms concurrently for smoother UI

## Gestures: Simultaneous Multi Gesture

- When users press and hold a cafe tile, it becomes active (highlighted with haptic feedback).
- While still holding, they can drag the tile to:
  - Move it into a folder,
  - Drop it on the Trash button to delete
- How It Works
- The LongPressGesture first activates the cafe tile (dragging = cafe), giving tactile feedback so users know it’s ready to move.
- At the same time, a DragGesture runs simultaneously, tracking the user’s finger and detecting direction and distance.
- When released, we check:
  - If dropped on a folder -> move cafe.
  - If dropped on trash -> delete cafe.
  - If swiped left past a threshold -> delete cafe.
  - Otherwise -> snap back (cancel)

## UIKit + SwiftUI

This component demonstrates how SwiftUI and UIKit can work together seamlessly when SwiftUI alone doesn’t provide a required feature (in this case, the system camera).

- Why UIKit is used
  - SwiftUI doesn’t yet include a native camera view.
  - UIKit, however, provides UIImagePickerController, a powerful built-in class that can handle both camera capture and photo library selection.
  - To bridge UIKit’s view controller into SwiftUI, we use the UIViewControllerRepresentable protocol.

Although MemoriesGrid is implemented primarily in SwiftUI, it still relies on UIKit for subtle yet important system interactions. UIKit’s UIImpactFeedbackGenerator adds tactile haptic responses when users open or delete memories.

# Our Moment to Shine

1. Innovative Gesture System

   - Built using a custom drag gesture recognizer that differentiates between horizontal (swipe) and vertical (scroll) movements.
   - Implements direction locking and threshold based feedback:
     - Once a swipe passes the threshold, haptic feedback confirms the “Like” or “Nope” action.
     - On completion, the card animates off-screen, triggering appropriate state updates.

2. Interactive Visual Feedback

   - Real-time color overlays (green for Like, red for Nope) blend softly into the gradient card background.
   - A BadgeView overlay (“LIKE” or “NOPE”) appears and fades naturally with the swipe gesture.

3. Fluid Motion & Animation

   - All interactions use spring based physics animations (.spring(response:dampingFraction:)) to mimic real world movement and bounce.
   - Gestures integrate with rotation effects and depth shadows that respond to user input, providing a rich, layered feel.

4. Reusable Card Architecture

   - The card encapsulates:
     - PhotoCarousel: a swipeable photo gallery using AsyncImage.
     - AmenityChips and SpecialsStripGeneric: reusable horizontal strips for café amenities and deals.
     - AddressBlock and RatingPill: small, reusable subcomponents
     - Designed for independent use: represent cafes

5. Dynamic State and Navigation
   - Taps open a MenuView via NavigationLink, while swipes trigger logical outcomes (onSwiped(liked: Bool)).
   - Integrates with an AuthManager to update pinned cafes on the backend.
   - Uses a shared LocationManager to compute live distance strings for each cafe.

### What “threshold” really does here

- Direction lock: first decide which axis the gesture intends (horizontal vs vertical). This prevents accidental vertical scrolls from counting as swipes.
- Arming threshold (feedback stage): once drag distance crosses a smaller bound, we “arm” the card: show stronger visuals + 1 haptic. If the user drifts back under it, we “disarm” (no commit).
- Commit threshold (decision stage): on end, combine actual drag with momentum (predicted end) to compute an effective displacement. If that crosses the commit threshold -> finalize LIKE/NOPE and fling off screen; else snap back.

##

## References

- https://developer.apple.com/design/human-interface-guidelines
- https://developer.apple.com/design/
- https://developer.apple.com/sf-symbols/
- https://designsystems.surf/design-systems/apple

