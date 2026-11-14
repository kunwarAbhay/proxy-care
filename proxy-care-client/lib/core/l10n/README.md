# core/l10n

Localization with Flutter's ARB tooling (`flutter gen-l10n`, configured in
`l10n.yaml`).

- `arb/app_en.arb`: every user-facing string. English only for now; add
  `app_<locale>.arb` to add a language.
- `generated/`: output of `flutter gen-l10n` (`make gen`). Committed and
  checked by CI; never edit by hand.
- `error_messages.dart`: the central failure → message mapping
  (`failureMessage`, `fieldErrorMessage`). Screens never show backend
  messages, exception text or stack traces.
