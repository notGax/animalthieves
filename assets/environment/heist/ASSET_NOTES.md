# Heist environment art

All textures in this directory were generated for this project with the built-in image generation tool and are original assets. No external texture pack is required.

## painted_surfaces.png

The active 2x2 albedo atlas used by `surfaces.gdshader`: aged mossy brick, damaged checkerboard ceramic tiles, weathered wood, and oxidized painted metal, repainted in the game's softer pastel palette. The shader projects each quadrant in world space so large walls and floors keep a consistent material scale. Asphalt uses shader grain. Roughness and metalness are shader parameters rather than separate photographed PBR maps.

## surface_atlas.png

The original first-pass atlas with the same four surfaces in a grimmer palette. Kept as a reference; the world scene currently binds `painted_surfaces.png`.

## item_sprites.png

A 4x4 sprite sheet of hand-painted item and character icons used by the inventory, the trader shop and the in-world tool HUD through `ItemDatabase.art_icon(index)`:

- Row 1: rotten cheese, jailhouse moonshine, suspicious canned food, stolen household goods.
- Row 2: grappling hook, water gun, slime crystal, jetpack.
- Row 3: shopping cart, mini truck, racecar, production blueprint.
- Row 4: the rat, boar, bird and lizard transformation heads used in the trader's form-upgrade rows.

## shop_posters.png

A 2x2 atlas of illustrated store posters: Rat Mart, Boar Hardware, Bird Seed & Co. and Cold Blood Electronics. The world builder places them as wall posters inside each store and as a four-poster target wall behind the hideout ladder.

## surfaces.gdshader

Projects each painted quadrant in world space so large walls and floors keep a consistent material scale. Asphalt uses shader grain. Roughness and metalness are shader parameters rather than separate photographed PBR maps.

## Art direction

Characters and environments follow the intended look: chunky soft-edged low-poly shapes with muted pastel colors, expressive first-person mitten hands for grabbing, carrying and tool use, and large reactive eyes on every character that track players, held cargo and nearby threats.