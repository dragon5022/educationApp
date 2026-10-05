/// Every SharedPreferences key the TEEN app uses, in one place (cloud sync
/// mirrors exactly these).
///
/// The TEEN web pages (ark-top.html and the 21 stage pages) store NOTHING in
/// localStorage: there is no saved progress, and the BGM switch resets on
/// every page load. So there are no web key names to mirror; the keys below
/// are app-only additions, prefixed `ark_teen_` so they never collide with
/// the KIDS app's `ark_*` web keys. Values are strings/ints like the web's
/// localStorage conventions ('1' / '0' flags).
///
/// | key                          | type   | meaning                                   |
/// |------------------------------|--------|-------------------------------------------|
/// | `ark_teen_bgm`               | String | '1' music on (default) / '0' off          |
/// | `ark_teen_best_<page>_<Lv>`  | int    | best score, e.g. ark_teen_best_e-bunpou_Lv2|
/// | `ark_teen_rank_<page>_<Lv>`  | String | rank of that best score (S/A/B/C/D)       |
/// | `ark_teen_plays_<page>`      | int    | finished games on that stage              |
abstract final class ProgressKeys {
  static const bgm = 'ark_teen_bgm';
  static String best(String page, String level) => 'ark_teen_best_${page}_$level';
  static String rank(String page, String level) => 'ark_teen_rank_${page}_$level';
  static String plays(String page) => 'ark_teen_plays_$page';

  /// Prefix shared by every key above (for sync / reset).
  static const prefix = 'ark_teen_';
}
