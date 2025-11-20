# draughts_engine

A robust and lightweight Dart library for managing the logic, rules, and state of a standard Draughts (Checkers) game.

This package handles the heavy lifting of game validation, allowing you to focus on building the UI for your Flutter app or web interface.

## Features

*   **Game State Management**: Tracks piece positions, current turn, and game history.
*   **Move Validation**: Ensures moves follow standard rules, including diagonal movement and distinct rules for Men vs Kings.
*   **Capture Logic**: Handles single captures and multi-jump chains.
*   **King Promotion**: Automatically promotes pieces when they reach the opposite end of the board.
*   **Win Detection**: Detects when a player has won (by eliminating all opponent pieces or blocking all moves).

## Getting started

Add the package to your `pubspec.yaml`: