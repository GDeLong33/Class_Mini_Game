# Class_Mini_Game

A simple Flutter brick breaker game built for the web, designed for iPhones in portrait mode.

## How to play

- Tap the play area to launch the ball.
- Hold the on-screen ◀ / ▶ buttons to move the paddle.
- Break all the bricks to advance to the next (faster) level.
- You have 3 lives; you lose one each time the ball falls past the paddle.
  When they're gone, tap **Restart** to play again.

On a computer you can also click and hold the arrows with the mouse, or use the keyboard:

| Key | Action |
| --- | --- |
| ← / → or A / D | Move paddle |
| Space or Enter | Launch ball / restart after game over |

## Play it on your computer (from GitHub)

### 1. Install the tools (one time only)

- **Git:** <https://git-scm.com/downloads>
- **Flutter SDK:** follow the guide for your system at
  <https://docs.flutter.dev/get-started/install> (choose **Web** as the target).
- **A browser:** Google Chrome or Microsoft Edge.

Check that Flutter is ready by opening a terminal and running:

```sh
flutter doctor
```

### 2. Download the game

```sh
git clone https://github.com/GDeLong33/Class_Mini_Game.git
cd Class_Mini_Game
```

No Git? On the [GitHub page](https://github.com/GDeLong33/Class_Mini_Game), click
**Code → Download ZIP**, unzip it, and open a terminal in the unzipped folder.

### 3. Run it

```sh
flutter pub get
flutter run -d chrome
```

Use `-d edge` instead if you have Edge rather than Chrome. The first launch takes a
minute to compile; then the game opens in a new browser window.

In the terminal: press `r` to reload after changing code, or `q` to quit.

**Using VS Code?** Open the folder, install the **Flutter** extension, then press
**F5** and pick **Brick Breaker (Edge)**.

### Get the latest version later

```sh
git pull
flutter run -d chrome
```

## Tips for testing

- **See the iPhone layout:** in the browser press F12, then Ctrl+Shift+M
  (Cmd+Shift+M on Mac), and choose an iPhone from the device list.
- **Play on a real iPhone:** with the phone on the same Wi-Fi as your computer, run

  ```sh
  flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080
  ```

  then open `http://<your-computer-ip>:8080` in Safari.

## Build

```sh
flutter build web --release           # output in build/web
```

The files in `build/web` can be uploaded to any static web host.
