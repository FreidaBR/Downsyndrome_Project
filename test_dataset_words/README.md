# Dataset transcription test

This test runs the project's local Whisper-medium model with the kids-speech
adapter against audio files stored in labeled folders. Each folder name is the
expected transcript.

The test calls a transcript correct when it matches the folder name after
case-folding and removing whitespace and punctuation. This is an exact phrase
match, not a word-error-rate or semantic-similarity score. Failed transcriptions
are recorded as wrong and identified separately.

Run the full test from the project root:

```powershell
python test_dataset_words\evaluate_dataset.py
```

By default, the dataset is read from `~\Desktop\dataset words`, and
per-recording transcripts and match results are written to
`test_dataset_words\results.csv`. Override either path with `--dataset` or
`--output`. Use `--limit 5` for a quick check before evaluating the full set.
If an evaluation is interrupted, use `--resume` to reuse completed rows and
continue with the remaining files.

The evaluation requires the local Whisper-medium model cache, the adapter in
`whisper-kids-speech-model\whisper-kids-speech`, and `ffmpeg` on `PATH`.
