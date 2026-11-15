# SideQuest Flutter Frontend MVP

## What's new
- `frontend/lib/sidequest/sidequest_flow.dart` provides Create SideQuest, SideQuest HQ, Explore Destinations, Voting, and Final Plan screens.
- The existing `SideQuestScreen` entry point in `frontend/lib/screens/home_screen.dart` now opens the new flow.
- The group-chat banner in `frontend/lib/screens/group_chat_screen.dart` displays the current demo plan and opens it.
- Renamed `API_service.dart` to `api_service.dart` to match the existing imports on case-sensitive operating systems.

## Try it
1. Start your existing FastAPI backend if login and group chats need it.
2. In the `frontend` folder, run `flutter pub get` and `flutter run -d chrome`.
3. Open an existing group chat and click Start a SideQuest.
4. Choose one or more activities, a future date/time, and budget per person.
5. Explore local demo destinations. Nominate at least one in each category.
6. Vote using the demo participant picker to mimic multiple members.
7. View results and confirm the final plan.

## Important limitations
- **Frontend demo only**: plans, nominations and votes live in memory in `QuestDemoStore`. Reloading the app resets them. They are not synced between users/devices and are not yet part of real chat messages.
- **Demo participants**: You and Friend 1–3 are placeholders, not members loaded from the group database.
- **Sample destinations are fictional illustrative data** stored in `demoDestinations`, not real venue listings.
- **One current demo plan per group name**; this is not multi-plan history.
- Voting winners use highest vote count, then lowest destination ID to break ties.
- No backend files were modified.

## Backend integration later
Replace `QuestDemoStore` and `demoDestinations` with API calls for creation, catalog retrieval, nomination, votes and finalization; use real group IDs and member IDs. Wire realtime updates via the existing WebSocket mechanism.

## Verification
The Flutter/Dart SDK is not installed in this build environment, so `flutter analyze` and a runtime test could not be executed here. Run them locally before merging.
