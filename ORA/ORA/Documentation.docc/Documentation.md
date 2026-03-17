# ``ORA``

The Ora App's documentation presented by Sruthy and Sukhman

## Overview

Ora aims to address this issue by providing a simple and intuitive way for users to find new cafes in Melbourne. The app contains features such as finding cafes near you, finding cafes with certain amenities or food/drinks, creating memories and just finding overall great cafes. This way whether you are on a date with your partner or on a date with your laptop you are able to quickly find new and exciting places.

In this app you will be able to find several unique UI/UX compoenents and multiple different features that makes this app unique. This includes things as **Swiping through Cafes**, **Pinning favorite cafes**, a memory section and profile section and a saved cafe section. 

Below you can see detailed documentation for this app by navigating through the apps MVVM structure. 


## Topics

Main entry to Ora
- ``ORAApp`` 

### Models
Core data types representing cafés, users, and memories.
- ``Cafe`` 
- ``Memory``
- ``MemoryDoc``
- ``MenuItem``
- ``SavedFolder``
- ``User``

### View
User Interfaces of the application

- ``SplashScreenView``
- ``LoginView``
- ``RadialCircle``
- ``WelcomeView``
- ``SignupView``

- ``ORABottomBar``
- ``ORAHeader``
- ``ORAMainView``
- ``ORATab``

- ``MapUtils``
- ``MapView``
- ``MKMapRepresentable``

- ``MenuCard``
- ``MenuView``

- ``EditProfileSheet``
- ``ProfileView``
- ``EmptyMemoriesView``
- ``MemoriesGrid``
- ``MemoryStore``
- ``AddMemorySheet``
- ``AvatarWithEditButton``
- ``PermissionManager``
- ``ProfileStat``
- ``CameraCaptureView``

- ``FolderSD``
- ``SavedFolderView``
- ``AsyncCafeImage``
- ``PlacePhotoCache``
- ``SavedStore``
- ``CafeImageCard``
- ``SavedCafesView``
- ``CafeDropDelegate``
- ``FolderChip``
- ``CafeRow``

- ``EmptyState``
- ``ErrorView``
- ``RecentSearchesSection``
- ``ResultRow``
- ``SearchLogic``
- ``SearchShortcutsSection``
- ``SearchStorage``
- ``SearchView``

- ``SwipeDeck``
- ``CafePageView``
- ``ORAReusableUI``
- ``SwipeCard``

- ``SettingsView``


### View Model 
Bridge between views and models
- ``CafeViewModel``
- ``SettingsViewModel``
- ``AuthManager``
- ``LocationManager``

### Services
Data handling and business logic
- ``MemoryService``
- ``S3Client``
- ``PlacesManager``
- ``UnsplashClient``
- ``Secrets``

### Utils
Helper functions and other utilities
- ``ThemeManager``
- ``AppColor``
- ``ORABackdrop``
- ``CoffeeLayout``
- ``CafeUtils``


### Trending Cafe Widget
- ``TrendingCafeWidget``



