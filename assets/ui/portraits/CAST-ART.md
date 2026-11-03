# HPA-689 cast art

The portraits and `assets/sprites/villagers.png` were generated with the
built-in image generation tool. The runtime portraits are fitted to a 300×420
transparent canvas; the three world sprites are cropped, alpha-thresholded,
and resized with nearest-neighbour sampling into 32×48 frames in Sato, Gen,
Hana order. Their visible feet align with the player sprite.

Portrait prompt shared by all three: transparent waist-up character portrait
for a cozy rural Japan farming game; 3/4 view, expressive face, refined 16-bit
Japanese farming RPG pixel art, warm earthy palette, dark brown outlines,
crisp pixel clusters, no scenery, text, or border.

- Sato-san: Japanese male shopkeeper in his 50s, short dark hair lightly
  graying, cream work apron over a muted indigo shirt, pencil and ledger pocket.
- Gen-san: Japanese retired farmer in his 70s, weathered skeptical face, gray
  hair, broad woven straw hat, moss-green farm jacket, earthy work clothes.
- Hana: Japanese station cafe owner in her late twenties, thoughtful expression,
  dark brown shoulder-length hair, dusty rose blouse, beige cafe apron.

World sprite prompt: use the matching generated portrait for character identity
and the existing player walk sheet for style and proportions; create one idle,
full-body sprite on a transparent background, with crisp low-resolution pixel
clusters and the portrait's clothing and colors. No ground or shadow.
