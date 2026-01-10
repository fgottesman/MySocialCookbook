# ClipCook Android Build Plan

> **Status**: Future TODO  
> **Estimated Timeline**: 6-8 weeks  
> **Last Updated**: January 9, 2026

This document outlines the complete plan for building an Android version of ClipCook that mirrors the existing iOS app.

---

## Table of Contents

1. [Overview](#overview)
2. [Your Action Items (Non-Technical)](#your-action-items-non-technical)
3. [Technical Implementation Plan](#technical-implementation-plan)
4. [Backend Changes](#backend-changes)
5. [Testing Strategy](#testing-strategy)
6. [Release Checklist](#release-checklist)

---

## Overview

### What We're Building

An Android app that replicates the full iOS ClipCook experience:

- Recipe feed with cards showing thumbnail, title, creator, and cook time
- Recipe detail view with ingredients (measurement conversion) and steps
- "Remix" flow for AI-powered recipe modifications
- Voice companion for hands-free cooking (TTS + Live Mode)
- Share Intent to import recipes from social media links
- Push notifications for recipe processing completion
- User authentication (Google Sign-In + optional Apple Sign-In)
- Favorites and user preferences

### Technology Stack

| Layer | Technology |
| :--- | :--- |
| Language | Kotlin |
| UI Framework | Jetpack Compose |
| Navigation | Compose Navigation |
| Networking | Ktor Client or Retrofit |
| Image Loading | Coil |
| Database/Auth | Supabase Kotlin SDK |
| Audio | Android AudioRecord / AudioTrack / Oboe |
| Push Notifications | Firebase Cloud Messaging (FCM) |
| Build System | Gradle (Kotlin DSL) |

---

## Your Action Items (Non-Technical)

These are the things you need to do before or during development. None require coding.

### Before Development Starts

| # | Task | Description | Time | Link |
| :--- | :--- | :--- | :--- | :--- |
| 1 | **Google Play Developer Account** | One-time $25 fee. Required to publish apps. | 5 min | [Register here](https://play.google.com/console/signup) |
| 2 | **Firebase Project** | Create a project in Firebase Console. Download `google-services.json`. | 15 min | [Firebase Console](https://console.firebase.google.com/) |
| 3 | **Enable Google Auth in Supabase** | In Supabase Dashboard → Authentication → Providers → Enable Google. You'll need OAuth credentials from Google Cloud Console. | 15 min | [Supabase Auth Docs](https://supabase.com/docs/guides/auth/social-login/auth-google) |
| 4 | **Provide Android Test Device** | Emulator works for UI, but Live Voice Mode requires a real Android phone for microphone testing. Any phone running Android 10+ works. | — | — |

### During Development

| # | Task | Description |
| :--- | :--- | :--- |
| 5 | **Review UI mockups** | I'll share screenshots of key screens for your approval before polish phase. |
| 6 | **Test on your device** | Install debug builds via USB or internal testing track. |

### Before Release

| # | Task | Description | Time |
| :--- | :--- | :--- | :--- |
| 7 | **App Signing** | Generate an upload key or use Play App Signing (recommended). I'll guide you through it. | 10 min |
| 8 | **Store Listing** | Prepare app icon (512x512), feature graphic (1024x500), screenshots, and description. Can reuse iOS assets. | 30 min |
| 9 | **Privacy Policy URL** | Same one you use for iOS App Store. | — |

---

## Technical Implementation Plan

### Phase 1: Project Setup & Foundation (Week 1)

#### 1.1 Initialize Android Project

```
Location: /Users/freddygottesman/fgottesman labs/ClipCook/android/
```

- Create new project in Android Studio with:
  - Minimum SDK: API 26 (Android 8.0) — covers 95%+ of devices
  - Target SDK: API 34 (Android 14)
  - Jetpack Compose enabled
  - Kotlin DSL for Gradle

#### 1.2 Configure Dependencies

Add to `build.gradle.kts`:

```kotlin
// Networking
implementation("io.ktor:ktor-client-core:2.3.7")
implementation("io.ktor:ktor-client-okhttp:2.3.7")
implementation("io.ktor:ktor-client-content-negotiation:2.3.7")
implementation("io.ktor:ktor-serialization-kotlinx-json:2.3.7")

// Supabase
implementation("io.github.jan-tennert.supabase:postgrest-kt:2.0.0")
implementation("io.github.jan-tennert.supabase:gotrue-kt:2.0.0")
implementation("io.github.jan-tennert.supabase:storage-kt:2.0.0")

// Image Loading
implementation("io.coil-kt:coil-compose:2.5.0")

// Firebase (Push Notifications)
implementation(platform("com.google.firebase:firebase-bom:32.7.0"))
implementation("com.google.firebase:firebase-messaging-ktx")

// Audio (optional, for advanced low-latency)
// implementation("com.google.oboe:oboe:1.8.0")
```

#### 1.3 Create App Configuration

Create `Config.kt` mirroring iOS `Config.swift`:

```kotlin
object AppConfig {
    const val API_ENDPOINT = "https://clipcook-production.up.railway.app"
    const val WS_ENDPOINT = "wss://clipcook-production.up.railway.app"
    const val SUPABASE_URL = "https://your-project.supabase.co"
    const val SUPABASE_ANON_KEY = "your-anon-key"
}
```

---

### Phase 2: Core Data & Networking (Week 1-2)

#### 2.1 Data Models

Port all models from `ClipCook/ClipCook/Models/`:

| iOS File | Android File | Notes |
| :--- | :--- | :--- |
| `Recipe.swift` | `Recipe.kt` | Use `@Serializable` annotation |
| `Ingredient.swift` | `Ingredient.kt` | — |
| `RecipeStep.swift` | `RecipeStep.kt` | — |
| `RecipeVersion.swift` | `RecipeVersion.kt` | — |
| `User.swift` | `User.kt` | — |

Example:

```kotlin
@Serializable
data class Recipe(
    val id: String,
    val title: String,
    val description: String?,
    val ingredients: List<Ingredient>,
    val steps: List<RecipeStep>,
    val thumbnailUrl: String?,
    val creatorName: String?,
    val platformSource: String?,
    val difficulty: String?,
    val cookingTime: String?,
    val step0Summary: String?,
    val step0AudioUrl: String?,
    val createdAt: String
)
```

#### 2.2 API Service

Create `RecipeService.kt` mirroring iOS `RecipeService.swift`:

```kotlin
class RecipeService(private val client: HttpClient) {
    
    suspend fun fetchRecipes(userId: String): List<Recipe> {
        return client.get("${AppConfig.API_ENDPOINT}/recipes") {
            parameter("userId", userId)
        }.body()
    }
    
    suspend fun processRecipe(url: String, userId: String): ProcessingResponse {
        return client.post("${AppConfig.API_ENDPOINT}/process-recipe") {
            contentType(ContentType.Application.Json)
            setBody(ProcessRecipeRequest(url, userId))
        }.body()
    }
    
    // ... other endpoints
}
```

---

### Phase 3: UI Implementation (Weeks 2-3)

#### 3.1 Screen Mapping

| iOS View | Android Composable | Priority |
| :--- | :--- | :--- |
| `ContentView.swift` | `MainScreen.kt` | P0 |
| `AuthView.swift` | `AuthScreen.kt` | P0 |
| `FeedView.swift` | `FeedScreen.kt` | P0 |
| `RecipeView.swift` | `RecipeDetailScreen.kt` | P0 |
| `VoiceCompanionView.swift` | `CookingModeScreen.kt` | P0 |
| `RemixSheet.swift` | `RemixBottomSheet.kt` | P1 |
| `NUXView.swift` | `OnboardingScreen.kt` | P1 |
| `FavoritesView.swift` | `FavoritesScreen.kt` | P1 |
| `ProfileView.swift` | `ProfileScreen.kt` | P2 |
| `UserPreferencesView.swift` | `PreferencesScreen.kt` | P2 |

#### 3.2 Design System

Create `DesignSystem.kt` with:

- Color palette (dark mode support via `isSystemInDarkTheme()`)
- Typography scale
- Common components (buttons, cards, chips)

#### 3.3 Navigation

```kotlin
@Composable
fun ClipCookNavHost(navController: NavHostController) {
    NavHost(navController, startDestination = "feed") {
        composable("feed") { FeedScreen(navController) }
        composable("recipe/{recipeId}") { backStackEntry ->
            RecipeDetailScreen(
                recipeId = backStackEntry.arguments?.getString("recipeId") ?: "",
                navController = navController
            )
        }
        composable("cooking/{recipeId}") { backStackEntry ->
            CookingModeScreen(
                recipeId = backStackEntry.arguments?.getString("recipeId") ?: "",
                navController = navController
            )
        }
        // ... other routes
    }
}
```

---

### Phase 4: Authentication (Week 3)

#### 4.1 Supabase + Google Sign-In

```kotlin
class AuthViewModel : ViewModel() {
    private val supabase = createSupabaseClient(
        supabaseUrl = AppConfig.SUPABASE_URL,
        supabaseKey = AppConfig.SUPABASE_ANON_KEY
    ) {
        install(GoTrue)
    }
    
    suspend fun signInWithGoogle(context: Context) {
        supabase.gotrue.loginWith(Google) {
            // Launches Google Sign-In flow
        }
    }
    
    fun getCurrentUser(): User? {
        return supabase.gotrue.currentUserOrNull()
    }
}
```

#### 4.2 Session Persistence

- Use `DataStore` (Android's modern SharedPreferences) to persist auth tokens
- Auto-refresh tokens on app launch

---

### Phase 5: Live Voice Mode (Weeks 4-5) ⚠️ Critical Path

This is the most complex component. It requires:

1. WebSocket connection to `/live-cooking`
2. Real-time microphone capture at 16kHz
3. Real-time audio playback at 24kHz
4. Sample rate conversion (device native → 16kHz)

#### 5.1 LiveVoiceManager.kt

```kotlin
class LiveVoiceManager {
    private var webSocket: WebSocket? = null
    private var audioRecord: AudioRecord? = null
    private var audioTrack: AudioTrack? = null
    
    // Input: 16kHz mono PCM (what backend expects)
    private val inputSampleRate = 16000
    private val inputChannelConfig = AudioFormat.CHANNEL_IN_MONO
    private val inputEncoding = AudioFormat.ENCODING_PCM_16BIT
    
    // Output: 24kHz mono PCM (what Gemini sends back)
    private val outputSampleRate = 24000
    private val outputChannelConfig = AudioFormat.CHANNEL_OUT_MONO
    private val outputEncoding = AudioFormat.ENCODING_PCM_16BIT
    
    fun connect(recipeId: String, stepIndex: Int) {
        val url = "${AppConfig.WS_ENDPOINT}/live-cooking?recipeId=$recipeId&stepIndex=$stepIndex"
        
        val client = OkHttpClient.Builder()
            .readTimeout(0, TimeUnit.MILLISECONDS)
            .build()
        
        val request = Request.Builder().url(url).build()
        webSocket = client.newWebSocket(request, WebSocketListener())
    }
    
    fun startRecording() {
        val bufferSize = AudioRecord.getMinBufferSize(inputSampleRate, inputChannelConfig, inputEncoding)
        
        audioRecord = AudioRecord(
            MediaRecorder.AudioSource.VOICE_COMMUNICATION,
            inputSampleRate,
            inputChannelConfig,
            inputEncoding,
            bufferSize
        )
        
        audioRecord?.startRecording()
        
        // Read loop in coroutine
        viewModelScope.launch(Dispatchers.IO) {
            val buffer = ByteArray(bufferSize)
            while (isActive) {
                val bytesRead = audioRecord?.read(buffer, 0, bufferSize) ?: 0
                if (bytesRead > 0) {
                    webSocket?.send(buffer.toByteString(0, bytesRead))
                }
            }
        }
    }
    
    fun playAudio(data: ByteArray) {
        if (audioTrack == null) {
            val bufferSize = AudioTrack.getMinBufferSize(outputSampleRate, outputChannelConfig, outputEncoding)
            audioTrack = AudioTrack.Builder()
                .setAudioAttributes(AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build())
                .setAudioFormat(AudioFormat.Builder()
                    .setSampleRate(outputSampleRate)
                    .setChannelMask(outputChannelConfig)
                    .setEncoding(outputEncoding)
                    .build())
                .setBufferSizeInBytes(bufferSize)
                .setTransferMode(AudioTrack.MODE_STREAM)
                .build()
            
            audioTrack?.play()
        }
        
        audioTrack?.write(data, 0, data.size)
    }
}
```

#### 5.2 Challenges & Solutions

| Challenge | Solution |
| :--- | :--- |
| Device native sample rate varies (44.1kHz, 48kHz, etc.) | Use a resampler library or request 16kHz directly (works on most devices) |
| Audio latency | Use `AudioAttributes.FLAG_LOW_LATENCY` and tune buffer sizes |
| Background audio interruptions | Handle `AudioManager.OnAudioFocusChangeListener` |
| Bluetooth headset support | Configure `AudioManager.MODE_IN_COMMUNICATION` |

---

### Phase 6: Share Intent (Week 5)

#### 6.1 AndroidManifest.xml Configuration

```xml
<activity
    android:name=".ShareReceiverActivity"
    android:exported="true"
    android:theme="@style/Theme.Transparent">
    
    <intent-filter>
        <action android:name="android.intent.action.SEND" />
        <category android:name="android.intent.category.DEFAULT" />
        <data android:mimeType="text/plain" />
    </intent-filter>
</activity>
```

#### 6.2 ShareReceiverActivity.kt

```kotlin
class ShareReceiverActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        val sharedUrl = intent.getStringExtra(Intent.EXTRA_TEXT)
        
        if (sharedUrl != null && isValidRecipeUrl(sharedUrl)) {
            // Show processing UI
            setContent {
                ShareProcessingScreen(url = sharedUrl) {
                    // On success, open main app
                    startActivity(Intent(this, MainActivity::class.java))
                    finish()
                }
            }
        } else {
            Toast.makeText(this, "Invalid recipe link", Toast.LENGTH_SHORT).show()
            finish()
        }
    }
}
```

---

### Phase 7: Push Notifications (Week 6)

#### 7.1 FCM Service

```kotlin
class ClipCookMessagingService : FirebaseMessagingService() {
    
    override fun onNewToken(token: String) {
        // Send token to backend
        CoroutineScope(Dispatchers.IO).launch {
            registerDeviceToken(token)
        }
    }
    
    override fun onMessageReceived(message: RemoteMessage) {
        val title = message.data["title"] ?: "Recipe Ready!"
        val body = message.data["body"] ?: "Your recipe has finished processing."
        val recipeId = message.data["recipeId"]
        
        showNotification(title, body, recipeId)
    }
    
    private fun showNotification(title: String, body: String, recipeId: String?) {
        val intent = Intent(this, MainActivity::class.java).apply {
            putExtra("recipeId", recipeId)
        }
        
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent, 
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        val notification = NotificationCompat.Builder(this, "recipes")
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .build()
        
        NotificationManagerCompat.from(this).notify(System.currentTimeMillis().toInt(), notification)
    }
}
```

---

## Backend Changes

Only one new file is needed. No changes to existing endpoints.

### New File: `src/services/fcm.ts`

```typescript
import admin from 'firebase-admin';

// Initialize with service account
admin.initializeApp({
  credential: admin.credential.cert({
    projectId: process.env.FIREBASE_PROJECT_ID,
    clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
    privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
  }),
});

export async function sendAndroidNotification(
  deviceToken: string,
  title: string,
  body: string,
  data?: Record<string, string>
) {
  try {
    await admin.messaging().send({
      token: deviceToken,
      notification: { title, body },
      data: data,
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: 'recipes',
        },
      },
    });
    console.log('✅ FCM notification sent');
  } catch (error) {
    console.error('❌ FCM send error:', error);
  }
}
```

### Update: `src/services/notifications.ts`

Add platform detection and route to appropriate service (APNs or FCM).

---

## Testing Strategy

### Unit Tests

- Data model serialization/deserialization
- Measurement converter logic
- URL validation for share intent

### Integration Tests

- API calls to all endpoints
- Supabase auth flow
- WebSocket connection to `/live-cooking`

### Manual Testing Checklist

| Feature | Test Case |
| :--- | :--- |
| Feed | Recipes load, infinite scroll works, pull-to-refresh |
| Recipe Detail | Ingredients display, measurement toggle, steps scroll |
| Remix | Suggestion chips work, AI responds, "Let's Make It" saves |
| Cooking Mode | Step navigation, TTS plays, timer works |
| Live Mode | Mic captures, AI responds, low latency |
| Share | Share from Instagram/TikTok/YouTube launches app |
| Notifications | Receive notification when recipe finishes processing |
| Auth | Sign in with Google, session persists |

---

## Release Checklist

- [ ] All screens implemented and reviewed
- [ ] Live Mode tested on physical device with good latency
- [ ] Share Intent works with Instagram, TikTok, YouTube links
- [ ] Push notifications working end-to-end
- [ ] Dark mode tested
- [ ] Accessibility basics (content descriptions, touch targets)
- [ ] Crashlytics integrated for crash reporting
- [ ] ProGuard rules configured for release build
- [ ] App signing key generated/configured
- [ ] Store listing assets prepared
- [ ] Internal testing track uploaded
- [ ] Beta testing with 3-5 users
- [ ] Production release

---

## Questions to Answer Before Starting

1. **Google Sign-In Only or Also Apple?** Apple Sign-In on Android requires a web-based flow. Worth it for users who started on iOS?

2. **Minimum Android Version?** Recommended: Android 8.0 (API 26). Covers 95%+ of active devices.

3. **Tablet Support?** Same app works on tablets, but we could optimize layouts for larger screens.

4. **Wear OS?** Future consideration: companion app for cooking timers on smartwatches.

---

*When you're ready to start, just say the word and we'll kick off Phase 1.*
