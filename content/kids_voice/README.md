# KIDS 音声（有料問題ぶん）/ paid-question voice clips

`paid/audio/voice/{voca,lis,gram,talk}/KIDS_X_NNNN.mp3` — the school's recordings for the
questions flagged `free: false`. Not bundled in the app (size); upload to Firebase Storage so the
app downloads them after the purchase:

```
cd ark_core
node tool/media/upload_media.mjs ../content/kids_voice/paid --key service-account.json
```

Free-question clips live in `ark_busters_kids/assets/audio/voice/`. Both sets are produced by
`ark_core/tool/sheets/import_bank.py` from the question bank + voice package (see
`ark_core/doc/CONTENT_SHEETS.md`).
