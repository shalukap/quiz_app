# QuizMaster Premium — setup checklist

The app code is done. Premium stays **switched off** (the app behaves exactly like
the free version) until the steps below are finished and the RevenueCat key is set.

Pricing (per grade): **LKR 99 / month · LKR 270 / 3 months · LKR 999 / year**.
Free access: set 1 of every subject is free, set 2 unlocks with a rewarded ad,
sets 3+ need Premium for that grade. Sets users already unlocked with ads stay unlocked.

---

## 1. Google Play Console
1. **Setup → Payments profile**: create/confirm a merchant (payments) profile.
   Subscriptions cannot be sold without it.
2. Upload a build that includes billing (any build from this version onward) to
   **Internal testing** first — Play only lets you create products after a
   billing-enabled build has been uploaded.
3. **Monetize → Products → Subscriptions → Create subscription**, once per grade
   that has content:

   | Field | Value |
   |---|---|
   | Product ID | `premium_grade_10` (use the grade number) |
   | Name | `QuizMaster Premium – Grade 10` |
   | Benefits | All question sets for Grade 10 · No ads |

4. In each subscription add **3 base plans** (auto-renewing, no free trial):

   | Base plan ID | Billing period | Price |
   |---|---|---|
   | `monthly` | 1 month | LKR 99 |
   | `quarterly` | 3 months | LKR 270 |
   | `yearly` | 1 year | LKR 999 |

   Activate each base plan.
5. **Setup → License testing**: add your Gmail so you can buy with test cards
   (no real charge).

## 2. Connect Google Play to RevenueCat
1. Create a free account at app.revenuecat.com → **New project** “QuizMaster”.
2. **Add app → Google Play Store**, package name `com.judeshaluka.quiz_master`.
3. Upload a **Google service account JSON** with Play access
   (RevenueCat's guide: “Creating Play Service Credentials”). Allow up to 36 h
   for Google to activate the credentials.
4. Turn on **Real-time Developer Notifications** (RevenueCat shows the Pub/Sub
   topic to paste into Play Console → Monetization setup).

## 3. RevenueCat products, entitlements, offerings
For **each grade** (example: Grade 10):
1. **Products**: import `premium_grade_10:monthly`, `premium_grade_10:quarterly`,
   `premium_grade_10:yearly`.
2. **Entitlements → New**: identifier `grade_10`; attach all three products.
3. **Offerings → New**: identifier `grade_10`, with packages:
   - **Monthly** → `premium_grade_10:monthly`
   - **Three Month** → `premium_grade_10:quarterly`
   - **Annual** → `premium_grade_10:yearly`

> The identifiers must match exactly — the app looks for entitlement `grade_<n>`
> and offering `grade_<n>`.

### EB exams (one-time LKR 199)
EB1/EB2/EB3 are stored as grades 101/102/103 and use a one-time purchase per exam
instead of a subscription (same free rules: set 1 free, set 2 ad, sets 3+ Premium).
For each exam (example: EB1):
1. **Play Console → Monetize → Products → In-app products → Create product**:
   ID `premium_eb_1`, name `QuizMaster Premium – EB1`, price LKR 199. Activate it.
2. **RevenueCat → Products**: import `premium_eb_1` (it is a non-consumable).
3. **Entitlements → New**: identifier `grade_101`; attach `premium_eb_1`.
4. **Offerings → New**: identifier `grade_101`, with one **Lifetime** package → `premium_eb_1`.

Use `premium_eb_2` / `grade_102` and `premium_eb_3` / `grade_103` for EB2 and EB3.

## 4. Add the key to the app
RevenueCat → **Project settings → API keys** → copy the **Google Play public SDK key**
(starts with `goog_`). Then either:

- build with it:
  `flutter build appbundle --release --dart-define=REVENUECAT_ANDROID_KEY=goog_xxx`
- or paste it as the `defaultValue` in `lib/config/premium_config.dart`.

## 5. Test before release
1. Install the internal-testing build with a license-tester account.
2. Open a grade → subject → tap set 3 → paywall → subscribe (test card).
3. Check: all sets unlock, ads disappear, gold theme appears, Profile shows
   “Premium member” with **Manage** working.
4. Uninstall/reinstall → log in → **Restore purchases** should bring it back.
5. Test renewals quickly: test subscriptions renew every few minutes.

## 6. Policy items
- Update the **Privacy Policy** to mention purchases are processed by Google
  Play and RevenueCat.
- Play Console → **App content**: keep ads declaration (free users still see ads).

## Notes
- The web version (quizapp-e7f6f.web.app) can't sell Google Play subscriptions;
  it shows a notice that Premium is available in the Android app.
- Premium checks run in the app via RevenueCat. Firestore rules are currently
  fully open (`allow read, write: if true`), so question data itself is not
  protected server-side — tighten the rules before relying on Premium revenue.

---

# App Store (iOS)

iOS bundle ID: **`com.judeshaluka.quizmaster`** (iOS doesn't allow `_`, so it differs
from Android; RevenueCat links purchases by Firebase user ID, so Premium bought on
one platform works on the other).

## A. Apple Developer / App Store Connect
1. Enroll in the Apple Developer Program ($99/year).
2. **Certificates, IDs & Profiles → Identifiers → +** → App ID
   `com.judeshaluka.quizmaster`, enable **Sign in with Apple** and **In-App Purchase**.
3. **App Store Connect → Apps → +** → new iOS app with that bundle ID.
4. **Business → Agreements**: accept the **Paid Apps** agreement and add bank + tax
   info. Subscriptions can't be sold (or even tested) without it.

## B. Subscriptions in App Store Connect
App Store has no "base plans", so each grade gets its own **subscription group**
(separate groups let a user own several grades at once):

| Group | Product ID | Duration | Price |
|---|---|---|---|
| `Grade 10 Premium` | `premium_grade_10_monthly` | 1 month | LKR 99 tier |
| | `premium_grade_10_quarterly` | 3 months | LKR 270 tier |
| | `premium_grade_10_yearly` | 1 year | LKR 999 tier |

Repeat per grade. Each product needs a display name, description and a review
screenshot of the paywall.

## C. RevenueCat
1. Project → **Add app → App Store**, bundle ID `com.judeshaluka.quizmaster`.
2. Upload the **In-App Purchase key** (.p8) from App Store Connect → Users and Access → Integrations.
3. Import the iOS products and attach them to the **same** entitlements and
   offerings as Android (`grade_10` → Monthly / Three Month / Annual packages).
4. Copy the **App Store public SDK key** (`appl_…`).

## D. Firebase
1. Firebase Console → Project settings → **Add app → iOS**, bundle ID
   `com.judeshaluka.quizmaster`. Download `GoogleService-Info.plist`.
2. Run `flutterfire configure` to regenerate `lib/firebase_options.dart` for the new bundle ID.
3. Copy `REVERSED_CLIENT_ID` from the plist into `ios/Runner/Info.plist`
   (replace `com.googleusercontent.apps.REPLACE_WITH_REVERSED_CLIENT_ID`).
4. **Authentication → Sign-in method → Apple → Enable.**

## E. AdMob
Add an iOS app in AdMob, then put its app ID in `GADApplicationIdentifier`
(`ios/Runner/Info.plist`) and the iOS ad unit IDs in `lib/services/ad_helper.dart`.

## F. Build with Codemagic (no Mac needed)
1. Push the project to GitHub/GitLab and add it in codemagic.io.
2. **Team integrations → Developer Portal**: add an App Store Connect API key
   named `QuizMaster ASC key`.
3. Environment variable group `quizmaster_ios`:
   - `REVENUECAT_IOS_KEY` = `appl_…`
   - `GOOGLE_SERVICE_INFO_PLIST` = the plist base64-encoded
     (PowerShell: `[Convert]::ToBase64String([IO.File]::ReadAllBytes("GoogleService-Info.plist"))`)
   - `APP_STORE_APPLE_ID` = the numeric Apple ID from App Store Connect → App Information
4. Start the `ios-release` workflow → the build lands in TestFlight.

## G. Test & submit
1. TestFlight: sign in with Apple, Google and email; buy Premium with a
   **Sandbox** tester (App Store Connect → Users and Access → Sandbox).
2. Attach the subscription products to the version, fill in App Privacy,
   screenshots, privacy policy URL, and a demo login for the reviewer.
3. Submit for review.
