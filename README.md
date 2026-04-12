# Truss Calculator for MATLAB

Interactive 2D truss calculator written in MATLAB.

The tool lets you build planar truss models, define supports, loads, and cross sections, and compute member forces and support reactions. It also supports symbolic variables for many typical engineering exercise setups.

## Features

- Interactive 2D truss modeling in a MATLAB GUI
- Node, member, support, load, and cross-section editing
- Click-based placement for nodes, members, and loads
- Loads via `Fx/Fy` or total force plus angle
- Support types:
  - `No Support`
  - `Pinned Support`
  - `Roller Support`
  - `Fixed Support`
- Cross-section types:
  - `Circular`
  - `Tube`
  - `Rectangular`
- Symbolic variables such as `a`, `b`, `h`, `F`, `alpha`
- Optional preview values for symbolic models
- Result display for:
  - member forces
  - support reactions
- Switchable symbolic output style:
  - `sin/cos`
  - `Fraction/Root`

## Requirements

- MATLAB
- Symbolic Math Toolbox recommended

The calculator was tested in a newer MATLAB environment. If you plan to use older MATLAB versions, some GUI or string-handling features may require adjustments.

## Start

Open MATLAB in this folder and run:

```matlab
truss_calculator
```

## Notes

- The calculator is designed for 2D truss systems.
- Symbolic computations for very large models may still take noticeably longer than purely numeric cases.
- Existing models using older German support or section names are still accepted internally for compatibility.

## Files

- `truss_calculator.m`
  Main MATLAB GUI and solver.

## License

This project is licensed under the MIT License. See `LICENSE` for details.
