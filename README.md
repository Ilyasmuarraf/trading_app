# Pro Trade - Flutter Trading App

A highly performant, real-time mock trading application built with Flutter. This app features a live market feed, portfolio tracking, seamless order execution, and customizable watchlists.

## Tech Stack
* **Framework:** Flutter (Stable channel)
* **State Management:** Riverpod (`flutter_riverpod`)
* **Persistence:** `shared_preferences`
* **Core Architecture:** Granular state subscriptions for 60fps performance under heavy tick loads. Integer-based `paise` math to prevent floating-point drift.

## Run Instructions
This app requires zero external setup or backend configuration. The market data feed is simulated entirely locally.

1. Clone the repository.
2. Fetch the dependencies:
   ```bash
   flutter pub get