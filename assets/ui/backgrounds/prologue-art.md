# Prologue background art

HPA-1138's three 1280×720 paintings were generated with Codex's built-in
image generator, with the user's approval as a fallback for the requested
OpenAI Image API. The built-in tool did not expose a model identifier.
`intro.png` was the style reference for all three; `town-art-source.webp`
was an additional building-design reference for the station front.

The generated 1672×941 images were converted to RGB and resized to 1280×720
using Pillow's Lanczos resampling. The station image initially contained
black bars; the generator was asked to extend the painting over those bars
before resizing. No bars, portraits, truck, or UI are intended to be baked
into the assets.

## Prompts

### prologue-platform.png

> Use case: illustration-story. Create an original wide 16:9 game prologue background. The supplied image is a STYLE reference only: match its detailed painted pixel art, pixel scale, natural rural Japanese palette and soft atmospheric light; do not copy the farm. Scene: a small rural Japanese railway platform at 7 PM as dusk turns to night. A clearly TWO-CAR local train stands alongside the platform, warm illuminated windows, one lone lamp post, a modest canopy and an unlettered station name board. Quiet and slightly lonely. Landscape composition, keep the top and bottom margins and bottom third quiet for letterbox bars and dialogue. No people, no readable text, no UI, no logos or watermarks.

### prologue-station.png

> Use case: illustration-story. Create an original wide 16:9 game prologue background. Image 1 is the STYLE reference: match its detailed painted pixel art, pixel scale, rural Japanese palette and soft light. Image 2 is the BUILDING DESIGN reference only: interpret its small blue tiled-roof wooden rural station and neighboring wooden cafe as a cohesive street-level painted scene, no magenta or atlas. Dusk, front of the station with a vending machine, next to Hana's small cafe with a pink striped awning and warmly lit windows. Place station and cafe in the center and right, leaving the left third free of key detail for a portrait. Keep bottom third and top/bottom margins quiet for dialogue and letterbox. No people, no readable text, no UI, no logo or watermark.

Follow-up edit:

> Edit this background painting: remove the solid black bands at the top and bottom and extend the existing scene naturally to fill the entire 16:9 canvas edge to edge. Preserve the station, pink awning cafe, vending machine, composition, lighting and pixel-art style. Do not add text, people, letterboxing, borders or interface elements.

### prologue-road.png

> Use case: illustration-story. Create an original wide 16:9 game prologue background. Supplied image is a STYLE reference only: match its detailed painted pixel art, pixel scale, natural rural Japanese palette and soft light; do not copy the farm. A dirt country road climbs through wooded hills at late dusk, first few stars in the sky. The road runs from the lower left towards the centre right, with a clear unobstructed surface for a separate small truck sprite and headlight beam. Leave the road entirely empty: no truck, vehicle, people, lights or headlight beams. Keep the left third free of key detail for a portrait, and the bottom third and top/bottom margins quiet for dialogue and letterbox. No text, no UI, no logos or watermark.

Follow-up edit, using the scene 3 mockup as a placement reference:

> Edit Image 1, the pixel-art road background. Image 2 is a placement reference only, showing where a separately rendered truck will appear. Change the road geometry so its broad dirt surface runs diagonally from the lower left and PASSES DIRECTLY UNDER the truck's position in Image 2: around 54% of canvas width and 58% of canvas height, then continues up toward the centre right wooded hills. The surface must be empty and unobstructed there, with no fence or grass across it. Keep the style, wooded hills, dusk sky and stars of Image 1. Do not draw the truck, beam, person, text, UI or black bars from Image 2. Paint a continuous edge-to-edge 16:9 background.
