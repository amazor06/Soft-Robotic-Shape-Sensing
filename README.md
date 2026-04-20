# Optical Wedge Simulator

An interactive MATLAB-based simulation for modeling light transmission through adjacent 3D wedge geometries using ray tracing and Beer–Lambert attenuation.

---

## Overview

This project simulates an optical system consisting of:

- A fixed **LED light source**
- Two adjacent **3D right-triangular wedges**
- Two fixed **detectors**

Light rays are emitted from the LED, pass through the wedges, and are attenuated based on material thickness and path length. The system visualizes how geometric changes affect transmitted intensity.

---

## Features

- 3D visualization of optical geometry (LED, wedges, detectors)
- Real-time ray tracing simulation
- Adjustable parameters:
  - Vertical wedge shift (Z)
  - Horizontal wedge shift (Y)
  - Attenuation coefficient (α)
  - Ray density
- Separate visualization of:
  - Incoming rays
  - Transmitted (attenuated) rays
- Front-view projection for geometric clarity
- Live data extraction with:
  - Detector transmission
  - Average path length
  - Blocked-ray fraction
  - Sensitivity analysis

---

## Physics Model

The simulation uses the **Beer–Lambert Law**:

T = exp(-αL)

Where:
- `T` = transmission
- `α` = attenuation coefficient
- `L` = total path length through material

Additional modeling includes:
- Weighted ray contributions using angular dependence
- Numerical estimation of path length via sampling
- Finite-difference sensitivity analysis:
  
∂S/∂Z ≈ (S(Z+ε) − S(Z−ε)) / (2ε)
