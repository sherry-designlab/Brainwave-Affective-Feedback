# Brainwave Interactive Boids Art

This is a generative art project created with **Processing**. It uses EEG data from a Muse headband to control the behavior of a Boids flocking simulation.

## ✨ Features

- **Emotional Mapping:** Maps EEG (Alpha, Beta, Theta) to Valence/Arousal (Russell's Circumplex Model).
- **Interactive Flocking:** The boids change their speed, color, and cohesion based on your attention or positive/negetive emotion levels.
- **Visuals:** Includes particle trails and flow fields.

## 🛠 Dependencies

To run this code, you need:
1.  **Processing IDE** (Java mode).
2.  **oscP5** library (Install via "Sketch" -> "Import Library" -> "Add Library" -> search for "oscP5").
3.  **Muse 2 EEG Headband** (or an OSC simulator).
4.  **Mind Monitor** (Application)

## 🚀 How to Run

1.  Download this repository.
2.  Put MUSE 2 EEG headset
3.  Bluetooth -> Open Mindmonitor -> Connect
5.  Ensure your Muse 2 headband is streaming OSC data to port `8000` (e.g., using Mind Monitor or Muse Direct).
6.  Open `BrainwaveBoidsTimeVisualization.pde` in Processing.
7.  Run the sketch!
