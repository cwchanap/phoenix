# Phoenix task runner. Run `just` (no args) to list recipes.

set positional-arguments

# List available recipes (default)
default:
    @just --list

# Import assets, launch. Extra args go to Godot, e.g. `just run --headless --quit-after 5`
run *args:
    godot --headless --path . --import
    godot --path . "$@"
