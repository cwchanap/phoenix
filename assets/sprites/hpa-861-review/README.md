# HPA-861 world art sources

> **Post-HPA-863 state:** the accepted runtime art was promoted once to
> `assets/sprites/world-v2/` and this folder was pruned to the generation
> source sheets, this prompt record and `.gdignore`. The review scenes,
> previews, candidate atlases, split `ground-v2` tiles, extracted cutouts and
> `.import` sidecars are gone. The candidate notes below are retained as the
> historical HPA-861 review record; they describe files that no longer exist
> and are not runtime paths. Nothing under this folder may be referenced at
> runtime or included in an export.

The owner accepted the presented previews as looking good for now. The images
and scenes do not change the live farm or town. The homestead and field scenes show a subset of
the approved 48×40 plan at the existing 3× camera zoom; the town scene uses
the current town footprint locations. The PNGs with the same names are offline
approximations of those views.

The `ground-v2` shared-surface and transition candidates need wider
native-scale review, especially paving, water banks and multi-material corners.
The road edge line is a provisional
four-direction overlay previewed on the town road. The dry/wet soil atlas is
provisional, and some older cutouts may retain coloured fringes. Fence segments
have been previewed in a row, but corners and posts need a full placement check.
The transparent crop alternative uses separately generated stage-2 potato and
pumpkin sprites.
The new buildings' anchors and footprints have not been accepted in Godot.
The preview is not a final acceptance test.

Cutouts are bottom-aligned in transparent frames. Candidate multi-cell frames,
given as size and bottom-centre anchor in frame coordinates, are: farmhouse
224×192 at (112,192) for 3×3 cells; storehouse and greenhouse 320×256 at
(160,256) for 5×4; tool shed, shrine and camphor 160×144 at (80,144) for
2×2. Other cutouts use 96×96 frames at (48,96). These are provisional and
still require an in-engine footprint check. `crops-transparent-candidate.png`
is 128×144 with 32×48 frames and is shown in the review scenes.
`soil-states-candidate.png` is a 128×32 dry/wet atlas cropped from the
generated soil-state sheet. The farm and town prop candidate atlases preserve
their current 4×2 and 2×2 layouts, respectively.
The farm rows are house, market stall, broadleaf tree, rocks; wood fence,
workbench, village sign, empty reserved slot. The town rows are station and
seed shop; cafe and market stall. The crop rows are Turnip, Potato and Pumpkin,
each with four stages. The lidded shipping bin is `cutouts/shipping-bin.png`.
`farm-terrain-candidate.png` has four phase columns and, top to bottom, grass,
dirt, soil, fallow, yard, gravel, water, forest floor, paddy, reeds and road
rows. `town-terrain-candidate.png` has paving and road rows. Every cell is
64×32; these phase layouts require integration changes in HPA-863.

## Generation and processing

Generated with Codex's built-in image generation tool, using the ticket's
farm painting as the visual reference; the tool did not expose a model ID.
The source sheets were cropped and resized with nearest-neighbour sampling;
transparent sprites use thresholded alpha, and magenta-backed sources use
colour-keying. The ground materials sample the interior of generated swatches
and are masked to 64×32 diamonds. The offline previews composite these at 3×
with nearest-neighbour scaling. The town cutouts had bright red and magenta
background artefacts removed. The soil atlas uses separate generated dry and
wet samples.

`ground-v2` is a second experiment: each material samples a mirrored 2×2-cell
continuous texture. Each `*-phases.png` has four 64×32 cells ordered `(0,0),
(1,0), (0,1), (1,1)`; choose by the logical cell's `(x % 2, y % 2)`. Each
`A-to-B.png` contains 16 columns of vertex masks and four rows of those same
phases. A mask bit selects B at a logical cell corner: bit 0 is `(0,0)`, bit 1
`(1,0)`, bit 2 `(0,1)`, bit 3 `(1,1)`; all other corners select A. Neighboring
cells must agree on their shared corners. `grass-variants.png` has three rows
of grass detail choices, each with the same four phase columns; choices preserve
identical edge pixels for that phase. `multi-junctions.png` and its JSON index
contain 26 phase-specific
three-material tiles needed by the attached layout, using the same corner order.
For the experiment, a vertex's material is the majority of its four surrounding
cells, with alphabetic tie-breaking and outside cells treated as grass. The
layout normalizes path to dirt, field to soil, lot to yard, bamboo to grass and
pier to dirt. This policy is a review fixture, not an integration requirement;
changing it requires rechecking the junction index.
`repeat-check.png` and `transition-check.png` show two offline repeat checks;
the repeated grass and soil no longer show a diamond grid by eye, but the
mirrored larger pattern and other materials need further evaluation. An
independent comparison matched 36,864 interior pixels of a grass mosaic to
the shared texture. All 23 transition atlases matched their two endpoint
materials in all four phases, and a layout coverage check found candidate tiles
for all 1,920 cells. These checks do not prove perceptual quality or seamless
joins at multi-material corners. `road-edge-overlay.png` has four 64×32 frames,
in logical x-low, x-high, y-low, y-high order. The pale line is a pixel mask
drawn during post-processing.

The generated water transition candidates add a narrow shore-coloured band
during post-processing. Fence gaps are represented by leaving a segment out and
using the supplied single-post cutout at either end.

An isolated headless import and launch of all three review scenes completed.
The first import logged missing generated translation resources while scanning,
and macOS reported a system CA-certificate error; scene launches logged the
same certificate error but no scene-loading error. A native window was not
exposed to desktop automation, so the PNGs are not evidence of Godot's rendered
output and the scenes still need an in-engine visual check.

### Source prompts

**farm-source.png** (also used as a style reference for later sheets):

> Create a cohesive SOURCE SHEET for a 2:1 isometric pixel-art rural Japanese farming game, using the supplied image ONLY as the style and palette reference. Produce clean separated swatches and props for later manual extraction, arranged in evenly spaced rows against a completely flat solid magenta background, no labels, no borders. Ground materials: flat continuous grass, dirt path, rich field soil, fallow earth with weeds, pale packed yard earth, fine gravel, calm blue water, rice paddy, forest floor. Each material is a flat surface with NO raised sides, rims, diamond outlines, shadows, bevels or island. Also include isolated game props, each separate with generous magenta margin: rural Japanese kominka farmhouse, kura storehouse with white plaster and boarded door, small tool shed, torn vinyl greenhouse, little shrine and torii, well, bamboo fence, wooden fence, tree, wooden shipping bin. Props stand directly on the ground with NO grassy disc, NO base island, bottom-center ground contact. Same isometric viewpoint as reference, coherent sunny warm colors, handcrafted crisp pixel art at game sprite resolution. No text, no UI, no watermark. Do not render a complete scene; make a practical sheet with separate subjects.

**town-source.png**:

> Create a cohesive SOURCE SHEET for a 2:1 isometric pixel-art rural Japanese town in the exact visual style, palette, lighting and pixel scale of the two supplied references. This is a sprite-sheet source for a farming game, not a scene. Separate subjects with ample empty solid pure magenta background, no text or grid. Include two flat ground swatches: seamless unoutlined warm stone paving, and asphalt country road with a single pale edge line, no raised sides, no rims, no bevel or dark outline. Include four separate isolated isometric buildings: small rural train station, seed and hardware shop, cafe, open-air produce market stall. Include separate roadside village sign, mailbox, vending machine, small jizo statue, simple utility pole. Each prop stands directly on the ground, bottom center contact, NO grass island, no circular base, no shadow, no other objects touching. Crisp deliberate pixel art, no blur, no watermark.

**fences-source.png**:

> Create a practical separate-prop sprite source sheet for the isometric rural Japanese pixel art game shown. On pure solid magenta background, with generous empty gaps and no labels or borders: wooden field fence pieces that follow each of the two isometric diagonal directions, corner post, endpoint, opening; bamboo yard fence pieces following each of the two isometric diagonal directions, corner post, endpoint, opening; one plain farmhouse doorstep; small isolated riverbank reeds; a small stone well. Each piece separate and seen at same 2:1 isometric angle as reference, drawn straight on ground with no grass islands or cast shadows. Fence segments must be straight on opposing isometric axes rather than facing the viewer, to connect along the edges of a 64x32 isometric tile. Warm cohesive crisp pixel art, no text, no watermark.

**farm-transparent-source.png**:

> Create a source sheet of separately isolated rural Japanese pixel-art farming game props, matching the supplied references in warm palette, lighting and 2:1 isometric angle. True transparent background. Generous transparent space between props. No text and no framing. Include exactly: a kominka farmhouse with red tile roof, small wooden tool shed, well with blue roof, wooden lidded shipping bin, bamboo fence in two opposite isometric directions, wooden fence in two opposite isometric directions, a leafy tree, stone lantern, barrel, crate, and flower bed. Each prop stands directly on ground with bottom center contact, no grass island, no ground patch, no cast shadow. Preserve crisp pixel-art outlines without magenta fringe or soft edges.

**kominka-source.png**:

> Generate a single isolated kominka farmhouse sprite for an isometric rural Japanese farming game. Reference image defines pixel-art detail, warm colours, sunlight and viewing angle only; the building itself must be Japanese: broad dark charcoal tiled hip roof, white plaster and dark timber, sliding wooden entry, shallow eaves, grounded stone foundation. No European gables or chimney. The house represents a 3x3-cell footprint on a 64x32 isometric ground grid. Bottom-centre ground contact. True transparent background, no ground patch, no grass island, no extraneous props, no cast shadow. Hand drawn pixel art, crisp hard pixels, limited palette, no soft edging, no text.

**crops-transparent-source.png**:

> For the isometric pixel-art farming game in the reference, create twelve isolated crop sprites on a truly transparent background, precisely arranged as 4 columns and 3 rows with generous empty space between each. Row 1 is white purple-shouldered turnip, row 2 brown potato plant, row 3 orange pumpkin vine. Left to right each row shows four consistent growth stages, the first a tiny sprout, second a young identifiable crop, third a developed plant, fourth ripe. Isometric view, no dirt or shadows, each plant bottom-center ground contact. Use clean deliberately chunky pixel clusters suitable for reduction to 32x48, limited colors and hard edges. No text, no colored background, no borders or labels.

**potato-stage2-source.png**:

> Create exactly one isolated small stage-2 potato crop sprite matching the reference game and crop sheet, on a truly transparent background. A young small green potato plant with two clearly visible small golden-brown potatoes at its base; recognisably a potato plant, smaller than the mature potato in the crop sheet. Bottom-center ground contact, no soil patch, no shadow, no text. Crisp chunky pixel art, hard edges, warm palette.

**ground-materials-source.png**:

> Create a source sheet of flat, tileable pixel-art ground textures for a cozy rural Japanese farming game, matching the attached reference's warm colors and pixel scale. Exactly nine equal square swatches arranged in a clean 3 by 3 grid, separated by narrow pure magenta gutters. View each texture straight on, as flat material; no individual diamond tiles, no perspective, no borders, no raised edges, no shadows, no text. Top row: subtle green lawn texture with sparse small grass marks and no flowers; warm tan dirt path; fine dark brown field soil with understated texture. Middle row: overgrown fallow earth; pale packed yard earth; fine grey gravel. Bottom row: blue pond water; muted green forest floor; warm grey town paving. Treat each swatch as an unbroken repeating surface, with restrained contrast and no prominent large features; neighboring swatches should stay entirely separate. Crisp deliberately chunky pixel clusters, no smooth airbrushing or blur.

**road-paddy-source.png**:

> Create a source sheet of four square unbroken flat pixel-art ground textures for the rural Japanese isometric game in the reference. Arrange exactly 2 by 2 separate equal square swatches with pure magenta gutters: top left dark gray country asphalt, top right shallow irrigated rice paddy with short green rice shoots growing in orderly rows of water, bottom left riverbank reeds and damp soil, bottom right light tan paved town stone. Direct flat texture view, no diamond outlines, no borders, no raised edges, no text. The asphalt itself has no painted markings; road edge line will be a separate overlay. Match the warm crisp pixel art palette and illumination of the reference; no giant objects, no shadows, no airbrushing.

**plants-transparent-source.png**:

> Create a transparent source sprite sheet of distinct isolated outdoor plants and trees for the isometric rural Japanese pixel art game shown. Include one each: mature broadleaf tree, tall conifer, bamboo clump, persimmon tree with orange fruit, fruit tree with red fruit, wide large camphor tree, low green bush, grey rock cluster, tall river reeds. Arrange separately in evenly spaced rows with generous transparent gaps; nothing touches. Each object is isolated on true transparency with no grass disc, no ground patch, no cast shadow, and bottom-center ground contact. Match the reference's warm bright color palette and isometric view; chunky pixel art with crisp hard-edged pixels, no text.

**outbuildings-transparent-source.png**:

> Create two separate isolated pixel-art building sprites on true transparent background for the rural Japanese isometric farming game in the style of these references, with ample transparent gap between buildings. LEFT: a large old Japanese kura storehouse, white plaster walls, dark tiled roof, and the doorway clearly boarded shut with crossed rough wooden planks, 5 by 4 tile footprint. RIGHT: a smaller wooden tool shed with weathered corrugated metal roof, closed or open wood door, 2 by 2 tile footprint. Same 2:1 isometric angle, sunlit warm palette and crisp hard-edged pixel art, no grass islands, no grounds or shadows, each has bottom-center ground contact. No text, no borders, no extra buildings.

**soil-states-source.png**:

> Create source artwork for two matched 2:1 isometric farming-game soil overlays, side by side and isolated against pure magenta. LEFT is a single freshly tilled farm cell with subtle shallow parallel furrows in warm dark brown soil; RIGHT is the same tilled cell after watering, visibly darker moist rich brown with a few tiny blue-brown highlights. Both must have the identical 64x32 diamond footprint and matching textures, flat to the ground with no raised block, no rims, no outlines, no crops, no grass. Match the reference's warm crisp pixel-art game style; no text, no grid.

**decor-transparent-source.png**:

> Create a single transparent sprite source sheet for an isometric rural Japanese pixel-art farming game, matching the reference image's sunlit warm palette and pixel style. Make each object separately isolated with generous transparent space between objects in orderly rows: wooden workbench; laundry pole with hanging white and blue cloth; stack of wooden crates; one wooden barrel; tidy woodpile; scarecrow with straw hat; rain barrel with spigot; compost heap; flower bed; simple roofed build notice board; small wooden village sign; wood stakes linked by rope; wooden bench; wooden pier planks. No overlapping, no cast shadows, no ground, no grass islands, all bottom-center ground contacts. Hard pixel-art outlines, no text or labels.

**fences-transparent-source.png**:

> Create a transparent sprite source sheet for modular fence pieces in a cozy 2:1 isometric pixel-art farming game, matching the provided reference. Two rows with five separated items each and generous transparent gaps. Row 1 wooden field fence: one single-cell segment slanting down-right, one single-cell segment slanting down-left, one connected inside corner, one separate post, one open gateway with a post on each side and empty space in the middle. Row 2 same five shapes made from pale bamboo yard fencing. Every segment is one logical 64x32 diamond edge long, same post height and matching rail attachment points, so segments connect. No background, no ground, no grass, no cast shadow, no words. Crisp warm hard-edged pixel art.

**town-transparent-source.png**:

> Create a transparent-background source sheet of four isolated 2:1 isometric pixel-art buildings for the rural Japanese game shown in the reference. Exactly four separately spaced subjects in a 2x2 layout: rural train station, seed and hardware shop, cozy cafe, open produce market stall. Match the references' warm palette, lighting and crisp detailed pixel-art style. Each building stands directly on ground with bottom-center contact. No grass islands, no ground patches, no cast shadows, no borders, no text, and no background colors or fringe. Leave generous transparent gaps between buildings.

**pumpkin-stage2-source.png**:

> Create one isolated small stage-2 pumpkin crop sprite for the isometric pixel-art farming game in the references. Show a very small unmistakable round orange pumpkin at the base of a young green vine, with one or two leaves. The plant is smaller than the mature pumpkin in the reference sheet. True transparent background, no soil, no pot, no ground, no shadow, bottom-center contact. Warm crisp chunky pixels, no text.
