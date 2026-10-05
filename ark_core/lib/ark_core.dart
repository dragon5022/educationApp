/// Shared foundation for the ARK BUSTERS series (KIDS, TEEN, …).
///
/// - `ui.dart` — effects (Reveal, ShineSweep, ArtShadow…) and Pressable
/// - `content.dart` — question packs updated from a Google Sheet (no reinstall)
/// - `purchase.dart` — in-app purchase, restore, parent gate, offer codes
/// - `auth.dart` — Firebase login (school-issued IDs) and progress sync
library;

export 'auth.dart';
export 'content.dart';
export 'purchase.dart';
export 'ui.dart';
