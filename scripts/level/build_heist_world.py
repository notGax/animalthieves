"""Rebuild editable Godot scenes using only Python's standard library.
Run from any directory: python scripts/level/build_heist_world.py
"""
from pathlib import Path
import json
import random

ROOT = Path(__file__).resolve().parents[2]
rng = random.Random(18)

# ---------------------------------------------------------------------------
# PALETTE - single source of truth for every color the generator uses.
# Mirrors scripts/visuals/palette.gd (GDScript side). New geometry should
# reference ROLES (via C('role')) instead of raw hex so the art direction
# stays coherent. Dirty means colorful: mustard, mold, rose, plum, teal.
# ---------------------------------------------------------------------------
PALETTE = {
    # Rat Mart hero colors
    'cheese_yellow': 'e8b23a', 'cheese_pale': 'f2d98b', 'cheese_rind': 'b57a2a',
    'mold_green': '7fae3d', 'moss_deep': '4c7a3f',
    'brick_rose': 'c96a4f', 'brick_rose_mid': 'b4715c', 'brick_rose_deep': '8f4636', 'brick_deep': '6e3a34',
    'tile_pale': 'dfe9c9', 'tile_green': '8fb98f',
    'turquoise': '3fa8a0', 'turquoise_deep': '1f6b68', 'turquoise_light': '9ef0e4',
    'plum_ink': '1d1526', 'plum_panel': '2b2138', 'plum_mid': '463352',
    'moonshine_pink': 'e56ba0', 'moonshine_purple': '8a4fbf',
    'amber_light': 'ffb347', 'amber_hot': 'ffd27a', 'ember': 'ff7d31',
    'cream': 'fdf3d0', 'cream_dim': 'cfc3a8',
    'wood_warm': 'b4763f', 'wood_dark': '7a4b2a',
    'neon_teal': '35c2b5', 'neon_pink': 'ff5fa8',
    'awning_red': 'd94f4f', 'awning_cream': 'f5e6c8',
    'van_green': '9fc06a', 'asphalt': '3a4046',
    'steel': '9aa3ab', 'steel_dark': '4a5258',
    'gold': 'ffd24a', 'rat_grey': '8f9aa3', 'rat_pink': 'd89694',
}
# Roles that resolve to a painted-atlas ShaderMaterial (kind = atlas quadrant).
KIND_ROLES = {
    'brick_rose': 0, 'brick_rose_mid': 0, 'brick_rose_deep': 0, 'brick_deep': 0, 'moss_deep': 0, 'mold_green': 0,
    'tile_pale': 1, 'tile_green': 1,
    'wood_warm': 2, 'wood_dark': 2, 'cheese_rind': 2,
    'turquoise_deep': 3, 'steel': 3, 'steel_dark': 3,
    'asphalt': 4,
}
# Per-kind tint multiplying the painted atlas (warm rose brick, honey wood, teal metal).
KIND_TINT = {
    0: (1.08, 0.85, 0.82),
    1: (1.05, 1.04, 0.92),
    2: (1.12, 0.92, 0.78),
    3: (0.82, 1.02, 1.08),
    4: (1.0, 1.0, 1.0),
}
# Legacy hex -> role. Keeps every existing call site working while recoloring.
LEGACY = {
    # painted surfaces (kind 0-4)
    '66735f': 'brick_rose_mid', '738264': 'brick_rose', '56634f': 'brick_rose_deep', '4c5e53': 'brick_deep',
    '334c4d': 'brick_deep', '4f5b4d': 'brick_rose_deep', '465659': 'brick_rose_deep', '344548': 'brick_deep',
    '737b66': 'brick_rose_mid',
    '74755e': 'tile_pale', '636a56': 'tile_green', '5d6555': 'tile_green', '3d5352': 'tile_pale', '514d40': 'tile_pale',
    '785540': 'wood_warm', '69523e': 'wood_warm', '75634b': 'wood_warm', '876445': 'wood_warm',
    '857354': 'wood_warm', '867350': 'wood_warm', '8a785a': 'wood_dark',
    '445954': 'turquoise_deep', '243b40': 'turquoise_deep', '42564b': 'turquoise_deep', 'a0aaa0': 'steel',
    'a49c76': 'wood_warm', '3e6154': 'turquoise_deep', '657673': 'turquoise_deep', '273c41': 'steel_dark',
    '263036': 'asphalt',
    # flat colors
    '293a39': 'plum_ink', '6a7470': 'cream_dim', 'a0a28b': 'cream_dim', 'd6ba70': 'cheese_yellow',
    '243c3d': 'plum_panel', 'ffd48b': 'amber_hot', '607371': 'cream_dim', '807258': 'wood_dark',
    'b78959': 'wood_warm', '182b30': 'plum_ink', '708e81': 'turquoise', 'c7c1a1': 'cream_dim',
    '778c55': 'mold_green', '92aa8b': 'van_green', '294951': 'plum_panel', '17292e': 'plum_ink',
    'bcc385': 'cream', '8b403e': 'awning_red', 'c4ad79': 'awning_cream', 'bcc66d': 'cheese_pale',
    '9b784b': 'wood_warm', 'b58b70': 'brick_rose', '263c36': 'turquoise_deep', '7b8d7b': 'turquoise',
    '314c44': 'turquoise_deep', '916843': 'turquoise', '344c45': 'steel_dark', 'dce9b0': 'cheese_pale',
    '4a5a49': 'moss_deep', '172c2b': 'plum_ink', '817452': 'wood_warm', 'd9e792': 'cheese_pale',
    'ad9871': 'wood_warm', 'bd9659': 'amber_light', '70b3bb': 'neon_teal', 'a7d9a0': 'mold_green',
    '586b56': 'moss_deep', 'a18854': 'wood_warm', '405654': 'steel_dark', 'b5a06b': 'cheese_rind',
    '3c7381': 'turquoise_deep', '9cb8a1': 'cream_dim', '866943': 'wood_warm', '344338': 'brick_deep',
    'a27b48': 'cheese_rind', 'bd9153': 'amber_light', '913e37': 'neon_pink', '243c3e': 'plum_panel',
    'a1a082': 'cream_dim', '203a37': 'plum_ink', '647e79': 'turquoise_deep', '8faaa0': 'turquoise',
    '203331': 'plum_ink', '57716b': 'brick_rose_mid', '80724e': 'wood_dark', 'b0b69c': 'steel',
    '223a32': 'plum_ink', '71816b': 'steel', '637b70': 'turquoise', '182f32': 'plum_panel',
    '313c3c': 'plum_ink', '666b60': 'rat_grey', '777c70': 'rat_grey', 'bf8c81': 'rat_pink',
    'eee8c9': 'cream', '182528': 'plum_ink', 'a39e8b': 'cream_dim', 'd89694': 'rat_pink',
    'dfd7b5': 'cream', 'eae4cc': 'cream', '9ecec6': 'turquoise_light', '476671': 'turquoise_deep',
    '263f4a': 'plum_panel', 'bf9758': 'gold', 'd6b779': 'gold', '7e7860': 'steel_dark',
    'd4c69a': 'amber_hot', 'ddd3ae': 'cream', 'ed8439': 'ember', 'efc15d': 'amber_hot',
    '829e89': 'van_green', 'cbab63': 'cheese_yellow', 'ad5652': 'brick_rose',
    # merchandise
    'c5ce69': 'cheese_pale', '899d70': 'moonshine_purple', 'b68c68': 'brick_rose', 'd5b565': 'gold',
    '7d9348': 'mold_green', 'd7cfab': 'cream', '8e6541': 'wood_dark',
}

def C(role):
    return role

def resolve(color):
    # Accepts a PALETTE role, a legacy hex, or a raw hex; returns a hex string.
    role = LEGACY.get(color, color)
    if role in PALETTE:
        return PALETTE[role]
    return color

def vec(v):
    return 'Vector3(%s)' % ', '.join(str(round(x, 4)) for x in v)

class Scene:
    def __init__(self):
        self.resources = []
        self.nodes = []
        self.index = 0
        self.materials = {}
    def resource(self, kind, props):
        key = 'r%d' % (len(self.resources) + 1)
        self.resources.append('[sub_resource type="%s" id="%s"]\n%s\n' % (kind, key, props))
        return 'SubResource("%s")' % key
    def node(self, name, kind, parent=None, props=''):
        header = '[node name="%s" type="%s"' % (name, kind)
        if parent is not None:
            header += ' parent="%s"' % parent
        self.nodes.append(header + ']\n' + props + '\n')
        return name if parent == '.' else (parent + '/' + name if parent else '.')
    def mat(self, color, glow=False):
        # Legacy hexes resolve to palette roles; roles resolve to painted-atlas
        # kinds (shader materials with a per-kind tint) or flat standard materials.
        resolved = LEGACY.get(color, color)
        key = (resolved, glow)
        kind = None if glow else KIND_ROLES.get(resolved)
        if kind is not None:
            if key not in self.materials:
                tint = ', '.join(str(round(v, 3)) for v in KIND_TINT[kind])
                self.materials[key] = self.resource('ShaderMaterial', 'shader = ExtResource("surface")\nshader_parameter/atlas = ExtResource("atlas")\nshader_parameter/surface_kind = %d\nshader_parameter/tile_size = 4.0\nshader_parameter/tint = Color(%s, 1)' % (kind, tint))
            return self.materials[key]
        if key not in self.materials:
            hex_color = PALETTE.get(resolved, resolved)
            if len(hex_color) != 6:
                print('PALETTE WARNING: unknown color %r' % color)
                hex_color = 'ff00ff'
            rgb = tuple(int(hex_color[i:i+2], 16)/255 for i in (0, 2, 4))
            c = 'Color(%s, 1)' % ', '.join(str(round(x, 4)) for x in rgb)
            p = 'albedo_color = %s\nroughness = 0.82' % c
            if glow:
                p += '\nemission_enabled = true\nemission = %s\nemission_energy_multiplier = 2.2' % c
            self.materials[key] = self.resource('StandardMaterial3D', p)
        return self.materials[key]
    def box(self, parent, name, pos, size, color, solid=True, glow=False, rotation=None):
        mesh = self.resource('BoxMesh', 'size = ' + vec(size))
        node = self.node(name, 'MeshInstance3D', parent, 'position = %s\nmesh = %s\nmaterial_override = %s' % (vec(pos), mesh, self.mat(color, glow)) + ('\nrotation_degrees = '+vec(rotation) if rotation else ''))
        if solid:
            body = self.node('Body', 'StaticBody3D', node, 'collision_layer = 2\ncollision_mask = 0')
            shape = self.resource('BoxShape3D', 'size = ' + vec(size))
            self.node('Collision', 'CollisionShape3D', body, 'shape = ' + shape)
        return node
    def cyl(self, parent, name, pos, radius, height, color, rotation=None, glow=False):
        mesh = self.resource('CylinderMesh', 'top_radius = %s\nbottom_radius = %s\nheight = %s\nradial_segments = 12' % (radius, radius, height))
        return self.node(name, 'MeshInstance3D', parent, 'position = %s\nmesh = %s\nmaterial_override = %s' % (vec(pos), mesh, self.mat(color, glow)) + ('\nrotation_degrees = '+vec(rotation) if rotation else ''))
    def sphere(self, parent, name, pos, scale, color, glow=False):
        mesh = self.resource('SphereMesh', 'radius = 1.0\nheight = 2.0\nradial_segments = 16\nrings = 8')
        return self.node(name, 'MeshInstance3D', parent, 'position = %s\nscale = %s\nmesh = %s\nmaterial_override = %s' % (vec(pos), vec(scale), mesh, self.mat(color, glow)))
    def text(self, parent, name, pos, text, size=40, color='e9e4cd', rotation=0):
        color = resolve(color)
        rgb = tuple(int(color[i:i+2],16)/255 for i in (0,2,4))
        self.node(name, 'Label3D', parent, 'position = %s\nrotation_degrees = Vector3(0, %s, 0)\ntext = %s\nfont_size = %s\npixel_size = 0.012\noutline_size = 5\nmodulate = Color(%s, 1)\nno_depth_test = false\ndouble_sided = true' % (vec(pos), rotation, json.dumps(text), size, ','.join(map(str,rgb))))
    def poster(self, parent, name, pos, kind, size=3.0, yaw=0):
        # Illustrated store poster from the 2x2 art atlas: 0 Rat Mart, 1 Boar, 2 Bird, 3 Cold Blood.
        if not hasattr(self, 'poster_mats'):
            self.poster_mats = {}
        if kind not in self.poster_mats:
            u, v = (kind % 2) * 0.5 + 0.005, (kind // 2) * 0.5 + 0.005
            self.poster_mats[kind] = self.resource('StandardMaterial3D',
                'albedo_texture = ExtResource("posters")\nroughness = 0.92\n'
                'uv1_offset = Vector3(%s, %s, 0)\nuv1_scale = Vector3(0.49, 0.49, 1)' % (u, v))
        mesh = self.resource('QuadMesh', 'size = Vector2(%s, %s)' % (size, size))
        return self.node(name, 'MeshInstance3D', parent,
            'position = %s\nmesh = %s\nmaterial_override = %s' % (vec(pos), mesh, self.poster_mats[kind])
            + ('\nrotation_degrees = Vector3(0, %s, 0)' % yaw if yaw else ''))
    def light(self, parent, name, pos, color='ffb347', energy=2, reach=12, spot=0):
        rgb = tuple(int(resolve(color)[i:i+2],16)/255 for i in (0,2,4))
        if spot:
            # Focal pool: a downward cone for checkout counters, pedestals and
            # other hero zones that must pop against the dimmer general wash.
            self.node(name, 'SpotLight3D', parent, 'position = %s\nrotation_degrees = Vector3(-90, 0, 0)\nlight_color = Color(%s, 1)\nlight_energy = %s\nspot_range = %s\nspot_angle = %s\nspot_attenuation = 1.3\nlight_indirect_energy = 1.1' % (vec(pos), ','.join(map(str,rgb)), energy, reach, spot))
            return
        self.node(name, 'OmniLight3D', parent, 'position = %s\nlight_color = Color(%s, 1)\nlight_energy = %s\nomni_range = %s\nomni_attenuation = 1.4\nlight_indirect_energy = 1.2' % (vec(pos), ','.join(map(str,rgb)), energy, reach))
    def save(self, path, ext=''):
        ext += '[ext_resource type="Shader" path="res://assets/environment/heist/surfaces.gdshader" id="surface"]\n[ext_resource type="Texture2D" path="res://assets/environment/heist/painted_surfaces.png" id="atlas"]\n'
        (ROOT/path).write_text('[gd_scene format=3]\n\n' + ext + '\n' + '\n'.join(self.resources+self.nodes), encoding='utf-8')

s = Scene()
s.node('HeistWorld', 'Node3D', props='script = ExtResource("world")')
road = s.node('Road', 'Node3D', '.')
store = s.node('RatStore', 'Node3D', '.')
base = s.node('Hideout', 'Node3D', '.')
cellar = s.node('Distillery', 'Node3D', '.')
interactions = s.node('Interactions', 'Node3D', '.')
loot = s.node('LootSpawns', 'Node3D', '.')

def interact(name, pos, hint, destination=None):
    props = 'position = %s\nmetadata/hint = %s' % (vec(pos), json.dumps(hint))
    if destination:
        props += '\nmetadata/destination = ' + vec(destination)
    s.node(name, 'Marker3D', interactions, props)

def stock(pos, item):
    s.index += 1
    s.node('Stock%03d' % s.index, 'Marker3D', loot, 'position = %s\nmetadata/scene = "res://scenes/items/heist/%s.tscn"' % (vec(pos), item))

def sign(parent, name, pos, width, text, color='b8d77c', size=54):
    x,y,z=pos
    s.box(parent,name+'Board',pos,(width,2.2,.25),'182f32')
    s.text(parent,name+'Text',(x,y,z+.15),text,size,color)

def barrel(parent, name, pos):
    x,y,z=pos
    s.cyl(parent,name,pos,.65,1.5,'785540')
    for i,dy in enumerate((-.55,.55)):
        s.cyl(parent,name+'Band'+str(i),(x,y+dy,z),.68,.12,'313c3c')
    s.box(parent,name+'Collider',pos,(1.05,1.45,1.05),'785540')

def rat(parent,name,pos,scale=1,chef=False):
    root=s.node(name,'Node3D',parent,'position = %s\nscale = %s' % (vec(pos),vec((scale,)*3)))
    s.sphere(root,'Body',(0,.8,0),(.65,.85,.5),'666b60')
    s.sphere(root,'Head',(0,1.7,.1),(.6,.5,.5),'777c70')
    for i,x in enumerate((-.45,.45)):
        s.sphere(root,'Ear'+str(i),(x,2.1,.03),(.28,.3,.12),'bf8c81')
        s.sphere(root,'Eye'+str(i),(x*.56,1.8,.53),(.1,.12,.065),'eee8c9')
        s.sphere(root,'Pupil'+str(i),(x*.56,1.8,.59),(.045,.065,.035),'182528')
    s.sphere(root,'Snout',(0,1.5,.58),(.3,.22,.35),'a39e8b')
    s.sphere(root,'Nose',(0,1.55,.9),(.13,.1,.1),'d89694')
    s.cyl(root,'Tail',(.6,.2,-.55),.075,1.3,'bf8c81',(60,0,-35))
    if chef:
        s.box(root,'Apron',(0,.9,.46),(.8,1,.09),'dfd7b5',False)
        s.cyl(root,'Hat',(0,2.25,0),.46,.45,'eae4cc')
        s.sphere(root,'HatTop',(0,2.53,0),(.62,.3,.48),'eae4cc')
    return root

# A continuous road with sidewalks and future store facades.
s.box(road,'Foundation',(22,-.55,0),(152,1,38),'293a39')
s.box(road,'Asphalt',(22,-.08,0),(152,.15,16),'263036')
for z in (-12,12):
    s.box(road,'Sidewalk'+str(z),(22,.06,z),(152,.25,8),'6a7470')
    s.box(road,'Curb'+str(z),(22,.12,z/abs(z)*8.2),(152,.35,.35),'a0a28b')
for x in range(-48,98,6):
    s.box(road,'Lane'+str(x),(x,.015,0),(3,.025,.15),'d6ba70',False)
for x in range(-42,94,18):
    for z in (-9,9):
        s.cyl(road,'LampPost%s_%s'%(x,z),(x,3,z),.12,6,'243c3d')
        s.box(road,'Lamp%s_%s'%(x,z),(x,6,z),(1.1,.18,.5),'ffd48b',False,True)
        s.light(road,'StreetLight%s_%s'%(x,z),(x,5.5,z),color='amber_light',energy=2.0,reach=12)
for x in (-54,98):
    s.box(road,'EndWall'+str(x),(x,3,0),(.6,6,38),'344548')
for z in ():
    s.box(road,'Boundary'+str(z),(55,3,z),(86,6,.5),'344548')
s.box(road,'SouthBoundary',(-20,3,19),(68,6,.5),'344548')
s.box(road,'NorthBoundary',(-36,3,-19),(36,6,.5),'344548')

for i,(x,z,title,sub,color) in enumerate([
    (-33,-18,'PAWN & CLAW','CLOSED / UNDER INVESTIGATION','dfa967'),
    (45,-18,'BOAR HARDWARE','DISTRICT 02 / COMING LATER','e5996f'),
    (74,-18,'COLD BLOOD ELECTRONICS','MECHA DRAGON / FINAL DISTRICT','b192d5'),
    (-27,18,'THE NIGHT MARKET','CLOSED / POLICE SEIZURE','77b8b2'),
    (17,18,'NO QUESTIONS ASKED','DELIVERIES AFTER DARK','d4bb70'),
    (61,18,'BIRD SEED & CO.','COMING LATER','94bdb4')]):
    if i in (1,2,5):
        continue
    face=s.node('Storefront'+str(i),'Node3D',road,'position = %s\nrotation_degrees = Vector3(0,%s,0)'%(vec((x,0,z)),0 if z<0 else 180))
    s.box(face,'Building',(0,4,-3),(23,8,6),'465659')
    s.box(face,'Shutter',(0,2,.08),(5,4,.25),'243b40')
    for y in range(1,8):
        s.box(face,'ShutterSlat'+str(y),(0,y*.5,.24),(5,.035,.035),'607371',False)
    sign(face,'ShopSign',(0,6,.3),22,title,color,40)
    s.text(face,'Status',(0,4.4,.3),sub,22,color)
    for wx in (-7,7):
        s.box(face,'Window'+str(wx),(wx,2.4,.08),(4,2.6,.2),'8ca198',False)
        s.box(face,'Board'+str(wx),(wx,2.4,.24),(4.5,.35,.1),'807258',False,rotation=(0,0,18))

gate=s.node('Gate','Node3D',road)
for z in range(-17,19,2):
    s.box(gate,'Fence'+str(z),(30,2.7,z),(.2,5.4,.14),'b78959')
s.box(gate,'Roadblock',(30,2,0),(.5,4,38),'624e3c')
s.text(gate,'Locked',(29.7,4,0),'EAST DISTRICT LOCKED\nRecover the Rat Mart recipe',35,'ffd18a',-90)
s.cyl(road,'Manhole',(0,.08,3),1.6,.16,'182b30')
for i in range(-2,3):
    s.box(road,'Grate'+str(i),(i*.4,.18,3),(.09,.04,2.2),'708e81',False)
s.text(road,'ManholeSign',(0,2,3),'THE UNDERCUT\n[F] Gang hideout',28,'a6e4bd')
interact('Manhole',(0,1,3),'Climb down to the hideout',(0,-10.9,25))
sign(road,'RoadName',(-12,4,14),14,'THE CROOKED MILE','f3cd87',47)
s.text(road,'RoadSubtitle',(-12,2.4,14.2),'01 / RAT MART     -     GATHER YOUR CREW',21)
for i in range(5):
    s.box(road,'Crosswalk'+str(i),(-4+i*2,.03,-11),(1,.025,5),'c7c1a1',False)
# Loot delivery bay and getaway van.
s.box(road,'DropZone',(9,.22,-12),(7,.08,5),'778c55',False)
s.text(road,'DropLabel',(9,2,-12),'LOOT LOADING BAY\nDrop carried items from inventory',24,'d6e9aa')
s.box(road,'Van',(17,1.6,-12),(3.4,2.5,6),'92aa8b')
s.box(road,'VanWindshield',(17,2.3,-8.95),(2.8,.9,.08),'294951',False)
for x in (15.3,18.7):
    for z in (-14,-10):
        s.cyl(road,'Wheel%s%s'%(x,z),(x,.65,z),.62,.28,'17292e',(0,0,90))

# Rat Mart: broad entrance, low aisles, counter, service corridor and rear arena.
s.box(store,'EntryApron',(0,-.18,-20.5),(34,.36,3),'74755e')
s.box(store,'Roof',(0,6.15,-43),(35,.3,42),'42564b')
s.box(store,'ArenaRoof',(0,7.2,-71),(35,.4,18),'42564b')
s.box(store,'Floor',(0,-.3,-43),(34,.6,42),'74755e')
for x in (-17,17):
    s.box(store,'SideWall'+str(x),(x,3,-43),(.5,6,42),'66735f')
for x in (-10,10):
    s.box(store,'FrontWall'+str(x),(x,2.8,-22),(14,5.6,.45),'738264')
    s.box(store,'DisplayWindow'+str(x),(x,2.9,-21.7),(8,2.4,.12),'bcc385',False)
    s.text(store,'WindowLetter'+str(x),(x,3,-21.58),'CHEESE & SPIRITS' if x<0 else 'OPEN ALL NIGHT',27,'263f37')
s.box(store,'EntranceHeader',(0,5.1,-22),(6,1.8,.5),'738264')
sign(store,'MainSign',(0,7,-22),30,'RAT MART','d4e5a0',96)
s.text(store,'Tagline',(0,5.9,-21.8),'FINE GOODS. QUESTIONABLE ORIGINS.',27,'f3d499')
s.box(store,'Awning',(0,4.3,-20),(32,.25,3.5),'8b403e')
for x in range(-15,16,2):
    s.box(store,'AwningStripe'+str(x),(x,4.45,-20),(.85,.05,3.5),'c4ad79',False)
s.light(store,'EntranceGlow',(0,4,-24),'amber_hot',2.6,14)
for x in range(-15,17,2):
    for z in range(-24,-62,-2):
        if (x+z)%4==1:
            s.box(store,'Tile%s_%s'%(x,z),(x,.013,z),(1.96,.02,1.96),'636a56',False)
for aisle,x in enumerate((-10,-3,4)):
    for segment,z in enumerate((-32,-42)):
        root=s.node('Aisle%d_%d'%(aisle,segment),'Node3D',store)
        for y in (.25,1.15,2.05):
            s.box(root,'Shelf'+str(y),(x,y,z),(2.2,.14,7),'a49c76')
        for dz in (-3.35,3.35):
            s.box(root,'Upright'+str(dz),(x,1.15,z+dz),(2.3,2.3,.14),'445954')
        for j in range(4):
            item=('rotten_cheese','moonshine','canned_food')[aisle]
            stock((x,1.3,z-2.3+j*1.5),item)
            # Upper shelf displays are fixed dressing; lower stock is replicated physics loot.
            s.box(root,'Display'+str(j),(x,2.32,z-2.3+j*1.5),(.65,.4,.65),('bcc66d','9b784b','b58b70')[aisle],False)
    s.text(store,'AisleSign'+str(aisle),(x,3.3,-28),('01 / CULTURED CHEESE','02 / CELLAR SPIRITS','03 / SURVIVAL TINS')[aisle],22,'e5dfad')
s.box(store,'Checkout',(11,1,-30),(3,2,9),'69523e')
s.box(store,'CounterTop',(11,2.07,-30),(3.4,.18,9.4),'263c36')
s.box(store,'Register',(11,2.55,-27),(1,.8,.8),'7b8d7b')
s.box(store,'RegisterScreen',(11,2.7,-26.56),(.7,.35,.06),'bde899',False,True)
for z in (-31,-33):
    stock((11,2.3,z),'stolen_goods')
sign(store,'CounterSign',(14,4.4,-36),5,'NO REFUNDS','eab180',25)
# Counter front dressing: the solid slab below is collision-final, so the
# segmentation is all garnish - crooked wood bays, a kick board, a top rail
# and two dividing posts that split the long run into three stations.
for ci,cz in enumerate((-28.2,-30.2,-32.2,-34.0)):
    s.box(store,'CounterBay'+str(ci),(9.42,1.05,cz),(.08,1.72,1.75),'wood_warm' if ci%2 else 'plum_panel',False,rotation=(0,0,2 if ci==1 else -1.5))
s.box(store,'CounterKick',(9.45,.28,-30),(.07,.36,9.4),'plum_ink',False)
s.box(store,'CounterRail',(9.45,1.97,-30),(.09,.15,9.4),'cheese_rind',False)
s.box(store,'CounterPostA',(9.5,2.6,-30.4),(.18,.95,.22),'wood_dark',False,rotation=(0,0,-2))
s.box(store,'CounterPostB',(9.5,2.6,-33.6),(.18,.95,.22),'wood_dark',False,rotation=(0,0,3))
# Checkout clutter: bell, card reader, tip jar, receipt roll, scale, samples.
s.cyl(store,'BellBase',(9.95,2.2,-28.3),.09,.04,'gold')
s.sphere(store,'BellDome',(9.95,2.26,-28.3),(.09,.07,.09),'gold')
s.sphere(store,'BellButton',(9.95,2.32,-28.3),(.03,.03,.03),'steel_dark')
s.box(store,'CardReader',(9.8,2.25,-29.3),(.22,.16,.14),'steel',False,rotation=(12,0,-8))
s.cyl(store,'TipJar',(10.15,2.31,-27.8),.1,.26,'turquoise_light')
s.cyl(store,'TipCoins',(10.15,2.36,-27.8),.07,.06,'gold')
s.cyl(store,'ReceiptRoll',(11.7,2.27,-28.3),.055,.2,'cream',(0,0,0))
s.box(store,'ScaleBase',(10.5,2.22,-32.2),(.4,.08,.4),'steel',False)
s.sphere(store,'ScaleDome',(10.5,2.34,-32.2),(.17,.14,.17),'steel')
s.box(store,'SampleTray',(10.1,2.2,-33.4),(.55,.05,.4),'wood_warm',False)
for tj in range(3):
    s.box(store,'SampleCube'+str(tj),(9.95+tj*.16,2.27,-33.4),(.11,.1,.11),'cheese_yellow',False)
s.text(store,'SampleTag',(10.1,2.5,-33.4),'FREE SAMPLE*',11,'cream_dim')
# Hanging checkout board on two cords from the ceiling beam.
s.box(store,'HangingBoard',(9.4,3.7,-30.2),(1.9,.7,.07),'plum_panel',False,rotation=(0,90,0))
s.text(store,'HangingBoardText',(9.32,3.7,-30.2),'CHECKOUT',15,'cream',90)
for hy in (3.95,):
    s.cyl(store,'BoardCord'+str(hy),(9.4,4.55,-30.6),.02,.75,'steel_dark')
    s.cyl(store,'BoardCord2'+str(hy),(9.4,4.55,-30.2),.02,.75,'steel_dark')
for i,z in enumerate((-40,-45)):
    s.box(store,'Fridge'+str(i),(14.7,1.65,z),(3,3.3,3.8),'a0aaa0')
    s.box(store,'FridgeInset'+str(i),(13.16,1.8,z),(.08,2.5,3.1),'314c44',False)
    s.light(store,'FridgeLight'+str(i),(12.6,2,z),'turquoise_light',1.2,5)
s.box(store,'BackPartition',(-5,2.8,-51),(24,5.6,.4),'56634f')
s.text(store,'StockroomArrow',(11,3.7,-50.7),'STOCKROOM  >\nKEEP OUT',27,'efc17d')
# Kitchen pass framing: the gap in the partition becomes a doorway, so the
# chef's arena reads as a destination from the shop floor instead of a hole.
s.box(store,'PassJambA',(7.3,2.8,-51),(.55,5.6,.75),'plum_panel',False)
s.box(store,'PassJambB',(16.7,2.8,-51),(.55,5.6,.75),'plum_panel',False)
s.box(store,'PassHeader',(12,5.45,-51),(10,.95,.75),'plum_panel',False)
s.text(store,'PassSign',(12,5.32,-50.55),'KITCHEN  >  STAFF ONLY',19,'amber_hot')
for pi,px in enumerate((-1.8,1.8)):
    s.cyl(store,'PassLamp'+str(px),(12+px,5.0,-50.6),.05,.35,'steel_dark')
    s.sphere(store,'PassBulb'+str(px),(12+px,4.78,-50.6),(.12,.15,.12),'amber_hot',True)
# Curtain valance strips hang above head height over the threshold.
for si,sx in enumerate((-2,-1,0,1,2)):
    s.box(store,'PassStrip'+str(si),(12+sx*.85,4.15,-50.85),(.55,1.5,.05),'awning_cream',False,rotation=(0,0,sx*1.5))
s.box(store,'PassRunner',(11.5,.02,-52.8),(3.2,.02,3.4),'awning_red',False)
for i in range(5):
    barrel(store,'StockBarrel'+str(i),(-13+i*2,.8,-55))
s.box(store,'CellarHatch',(11,.08,-55),(3,.15,3),'344842')
s.text(store,'CellarNotice',(11,2.5,-55),'DISTILLERY\n[F] Descend',25,'e6ba7f')
interact('CellarDown',(11,1,-55),'Descend to the distillery',(10,-10.9,-42))
for x in (-15,15):
    s.cyl(store,'Pipe'+str(x),(x,4.9,-42),.14,36,'916843',(90,0,0))
# General wash is deliberately lazy: the six shop tubes only carry the aisles,
# and the rear third drops off so the focal pools and glow props carry the
# hierarchy instead of a uniform bath of light.
for z in (-30,-42,-55):
    s.box(store,'CeilingBeam'+str(z),(0,5.7,z),(34,.35,.5),'344c45')
    for x in (-8,8):
        s.box(store,'Tube%s%s'%(x,z),(x,5.4,z),(3,.1,.25),'dce9b0',False,True)
        s.light(store,'ShopLight%s%s'%(x,z),(x,4.9,z),'amber_light',1.5 if z>-50 else 1.0,11 if z>-50 else 9)
# Focal pools: checkout, cheese display, cellar hatch and the recipe vault.
s.light(store,'CheckoutSpot',(11,4.3,-30),'amber_hot',3.4,8,spot=46)
s.light(store,'CheeseSpot',(-5,3.3,-24.5),'amber_hot',2.4,5,spot=38)
s.light(store,'CellarSpot',(11,4.3,-55),'turquoise_light',2.0,5,spot=36)
s.light(store,'RecipeSpot',(7,4.4,-74),'cheese_yellow',2.6,6,spot=40)
s.cyl(store,'CheeseGlowPool',(-5,.02,-24.5),1.4,.02,'amber_light',glow=True)
# Patched walls, wet stains and a rat-sized future shortcut.
for i in range(17):
    x,z=rng.uniform(-15,15),rng.uniform(-59,-27)
    s.cyl(store,'DampPatch'+str(i),(x,.032,z),rng.uniform(.3,1.1),.018,'4a5a49')
s.box(store,'RatHole',(-16.72,.65,-39),(.04,1.3,1.5),'172c2b',False)
s.text(store,'RatHoleHint',(-15.7,1.8,-39),'RAT SHORTCUT\nRequires rat form',16,'c9ba8a',90)

# The rear arena deliberately stages a boss model, not an implemented fight.
s.box(store,'ArenaFloor',(0,-.3,-71),(34,.6,18),'5d6555')
for x in (-17,17):
    s.box(store,'ArenaSide'+str(x),(x,3.5,-71),(.5,7,18),'4c5e53')
s.box(store,'ArenaBack',(0,3.5,-80),(34,7,.5),'4c5e53')
s.box(store,'KitchenIsland',(0,1,-76),(7,2,2.4),'817452')
# Live chef rat is created by the host-authoritative encounter system.
sign(store,'BossSign',(0,5.8,-79.7),22,'THE BIG CHEESE','e5bc7c',62)
s.text(store,'BossStage',(0,3.4,-79.65),'RECIPE VAULT / DEFEAT THE CHEF',22,'d8c29a')
recipe=s.node('RecipeDisplay','Node3D',store)
s.box(recipe,'Pedestal',(7,.7,-74),(1.5,1.4,1.5),'75634b')
s.box(recipe,'Recipe',(7,1.55,-74),(1,.12,.8),'d9e792',False,True)
s.text(recipe,'RecipeText',(7,2.7,-74),'ROTTEN CHEESE RECIPE\nDEFEAT THE CHEF TO CLAIM',22,'d9eda1')
interact('Recipe',(7,1,-72.5),'Inspect the chef recipe vault')
for x in (-11,11):
    s.light(store,'ArenaLight'+str(x),(x,5,-71),'ember',2.6,18)
    for z in (-66,-77):
        barrel(store,'ArenaBarrel%s%s'%(x,z),(x,.8,z))

# Underground hideout, separated vertically from the road.
s.box(base,'Floor',(0,-12.3,33),(30,.6,24),'3d5352')
for x in (-15,15):
    s.box(base,'Wall'+str(x),(x,-8.5,33),(.5,7,24),'334c4d')
for z in (21,45):
    s.box(base,'EndWall'+str(z),(0,-8.5,z),(30,7,.5),'334c4d')
s.box(base,'Ceiling',(0,-5.2,33),(30,.4,24),'273c41')
sign(base,'HideoutSign',(0,-7.2,21.3),20,'THE UNDERCUT','a6dabb',61)
interact('BaseExit',(0,-11,23),'Climb back to the road',(0,1,6))
s.text(base,'ExitLabel',(0,-9.5,23),'[F] UP TO THE ROAD',25,'d8cd9a')
for y in range(-11,-5):
    s.box(base,'LadderRung'+str(y),(0,y,21.65),(1.4,.12,.12),'ad9871')
for x in (-.8,.8):
    s.cyl(base,'LadderRail'+str(x),(x,-8.5,21.65),.07,6,'ad9871')
s.box(base,'TraderCounter',(-10,-11,30),(6,2,3),'876445')
rat(base,'Trader',(-10,-12,27),1.15)
sign(base,'TraderSign',(-10,-7.8,24),8,'THE PARTNER','e4ba78',35)
s.text(base,'TraderNote',(-10,-9.2,28.3),'EQUIPMENT SHOP\nTools for the whole crew',20)
for i, label in enumerate(('GRAPPLE','WATER GUN','SLIME CRYSTAL')):
    s.box(base,'Gear'+str(i),(-12+i*2,-9.8,30),(.7,.5,.7),('bd9659','70b3bb','a7d9a0')[i],False)
    s.text(base,'GearLabel'+str(i),(-12+i*2,-10.4,31.6),label,11)
for i in range(3):
    x=8
    z=26+i*7
    s.box(base,'MachinePad'+str(i),(x,-11.85,z),(7,.3,5),'586b56')
    s.text(base,'MachineLabel'+str(i),(x,-8,z-1),('01 / PRODUCTION','02 / EXPANSION SLOT','03 / EXPANSION SLOT')[i],23,'bce2a8')
    if i==0:
        barrel(base,'StarterMachine',(x,-10.9,z))
        s.cyl(base,'MachinePipe',(x+1,-10,z),.16,3,'a18854')
        s.box(base,'ControlBox',(x-1.3,-10.7,z),(1,1,.7),'405654')
        s.text(base,'AwaitingRecipe',(x,-9.2,z+1),'PASSIVE INCOME / COLLECT AT TERMINAL',16)
    else:
        for dx in (-2.8,2.8):
            s.box(base,'SlotEdge%s%s'%(i,dx),(x+dx,-11.65,z),(.12,.06,4),'b5a06b',False)
blueprint=s.node('Blueprint','Node3D',base,'visible = false')
s.box(blueprint,'RecipeBoard',(-3,-8.5,44.65),(6,3,.12),'3c7381',False)
s.text(blueprint,'RecipeUnlocked',(-3,-8.5,44.5),'ROTTEN CHEESE\nRECIPE RECOVERED\nInstall recipes at the trader',24,'d4edbd',180)
s.box(base,'PlanningTable',(-4,-11.2,38),(6,1.6,3),'857354')
s.box(base,'Map',(-4,-10.34,38),(4,.025,2),'9cb8a1',False)
s.text(base,'PlanLabel',(-4,-9,38),'PLAN THE NEXT JOB',24,'d7c599')
for x in (-10,0,10):
    s.cyl(base,'OverheadPipe'+str(x),(x,-6,33),.2,22,'866943',(90,0,0))
    s.light(base,'BaseLight'+str(x),(x,-6.8,34),'amber_light',2.2,18)
s.light(base,'BaseAccent',(0,-6.6,40),'turquoise_light',1.4,12)

# Basement distillery.
s.box(cellar,'Floor',(0,-12.3,-51),(30,.6,24),'514d40')
for x in (-15,15):
    s.box(cellar,'Wall'+str(x),(x,-8.5,-51),(.5,7,24),'4f5b4d')
for z in (-39,-63):
    s.box(cellar,'End'+str(z),(0,-8.5,z),(30,7,.5),'4f5b4d')
s.box(cellar,'Ceiling',(0,-5.3,-51),(30,.5,24),'344338')
sign(cellar,'CellarSign',(0,-7.4,-62.6),20,'JAILHOUSE RESERVE','e1b675',52)
interact('CellarUp',(10,-11,-41),'Return to the stockroom',(11,1,-53))
s.text(cellar,'Exit',(10,-9.5,-40.5),'[F] STOCKROOM',25)
for i,x in enumerate((-9,-2,5)):
    s.cyl(cellar,'Still'+str(i),(x,-9.8,-55),2,3.8,'a27b48')
    s.box(cellar,'StillCollision'+str(i),(x,-10,-55),(3.3,3.8,3.3),'a27b48')
    s.cyl(cellar,'StillNeck'+str(i),(x,-7.4,-55),.35,1.4,'bd9153')
    s.cyl(cellar,'PressurePipe'+str(i),(x,-6.8,-50),.18,10,'bd9153',(90,0,0))
    s.cyl(cellar,'Valve'+str(i),(x,-9.3,-52.8),.4,.12,'913e37',(90,0,0))
    s.text(cellar,'TankLabel'+str(i),(x,-9.5,-52.65),'BATCH 0%d\n140 PROOF'%(i+1),20)
for i in range(6):
    barrel(cellar,'Reserve'+str(i),(-11+i*2,-11.2,-43))
for x in (-8,8):
    s.light(cellar,'CellarLight'+str(x),(x,-7,-49),'ember',2.6,17)
s.text(cellar,'SabotageStaging',(0,-8.5,-39.4),'TURN THE THREE VALVES TO WEAKEN THE CHEF',20,'c6b38b',180)

# Repair patches, brick courses, exterior clutter, and workshop furnishings.
for side in (-1,1):
    for i,z in enumerate(range(-27,-60,-5)):
        s.box(store,'WallPatch%s_%s'%(side,i),(side*16.7,2.5,z),(.08,1.8,2.8),'737b66',False)
        for j in range(3):
            s.box(store,'PatchBoard%s_%s_%s'%(side,i,j),(side*16.61,2+j*.4,z),(.08,.12,3),'8a785a',False)
for i in range(12):
    x=rng.uniform(-15,15)
    z=rng.uniform(-57,-25)
    s.box(store,'Litter'+str(i),(x,.06,z),(.35,.025,.5),'c1b48c',False,rotation=(0,rng.uniform(0,180),0))
for i,x in enumerate((-11,-7)):
    s.box(store,'RoofVent'+str(i),(x,6.9,-39),(2,1.2,3),'657673')
    for j in range(5):
        s.box(store,'VentSlat%s_%s'%(i,j),(x,7.1,-37.46),(1.7,.05,.05),'243c3e',False)
for x in (-16,16):
    s.box(store,'FrontColumn'+str(x),(x,2.8,-21.6),(.6,5.6,.6),'a1a082')
for i in range(2):
    s.box(road,'Dumpster'+str(i),(-20-i*3,1,-15),(2.4,2,2),'3e6154')
    s.box(road,'DumpsterLid'+str(i),(-20-i*3,2.08,-15),(2.6,.18,2.2),'203a37')
# A parked cart establishes the loading route; a movable cart is a future equipment system.
cart=s.node('ParkedShoppingCart','Node3D',road,'position = Vector3(5, 0, -18)')
s.box(cart,'BasketFloor',(0,.7,0),(1.1,.12,1.6),'647e79')
for side in (-.55,.55):
    for j in range(6):
        s.box(cart,'Wire%s_%s'%(side,j),(side,1.1,-.7+j*.28),(.045,.8,.045),'8faaa0',False)
    s.box(cart,'Rim'+str(side),(side,1.5,0),(.07,.07,1.6),'8faaa0',False)
    for z in (-.6,.6):
        s.cyl(cart,'Wheel%s_%s'%(side,z),(side,.25,z),.22,.12,'203331',(0,0,90))
s.box(cart,'Handle',(0,1.55,1),(1.25,.09,.09),'9cad78',False)
for z in (29,37,43):
    for x in (-14.6,14.6):
        s.box(base,'Pillar%s_%s'%(x,z),(x,-8.5,z),(.5,7,.7),'57716b')
for i in range(4):
    s.box(base,'BenchCrate'+str(i),(-12+i*2,-11.5,42),(1.7,1,1.5),'867350')
s.box(base,'Pegboard',(-14.6,-8.7,35),(.15,2.2,5),'80724e',False)
for i in range(5):
    s.cyl(base,'Tool'+str(i),(-14.4,-8.7,33.3+i*.8),.07,1.2,'b0b69c')
for i in range(3):
    s.box(cellar,'Drain'+str(i),(-8+i*8,-11.97,-48),(2,.025,.7),'223a32',False)
    for j in range(7):
        s.box(cellar,'DrainBar%s_%s'%(i,j),(-8+i*8-.8+j*.25,-11.94,-48),(.04,.025,.65),'71816b',False)

# Interactive stations and shortcut markers.
interact('Trader',(-10,-11,32),'Trade equipment, install recipes and upgrade forms')
interact('Extract',(9,1,-12),'Sell bagged loot and nearby cargo')
interact('CollectIncome',(5,-11,25),'Collect production income')
interact('Replay',(-4,-11,38),'Restock all stores for another heist')
interact('RatTunnelIn',(-15.5,1,-39),'Slip through the rat tunnel',(-12,1,-63))
interact('RatTunnelOut',(-12,1,-63),'Return through the rat tunnel',(-14.5,1,-39))
for i,x in enumerate((-9,-2,5)):
    interact('Valve'+str(i),(x,-11,-51.7),'Sabotage distillery valve %d'%(i+1))
s.text(base,'IncomeLabel',(5,-9,25),'[F] COLLECT INCOME',23,'c7df8e')
s.text(base,'ReplayLabel',(-4,-9.8,39.7),'[F] RESTOCK STORES',20,'c7df8e')
# Three additional stores use the same physical loot and combat systems.
expansion=s.node('Expansion','Node3D','.')
for tier,x,z,orientation,title,color in [
    (1,45,-18,0,'BOAR HARDWARE','amber_light'),
    (2,61,18,180,'BIRD SEED & CO.','neon_teal'),
    (3,74,-18,0,'COLD BLOOD ELECTRONICS','turquoise_light')]:
    room=s.node('Store%d'%tier,'Node3D',expansion,'position = %s\nrotation_degrees = Vector3(0,%s,0)'%(vec((x,0,z)),orientation))
    s.box(room,'Floor',(0,-.3,-21),(24,.6,42),'74755e')
    s.box(room,'Roof',(0,7,-21),(24,.4,42),'42564b')
    s.box(room,'BackWall',(0,3.5,-42),(24,7,.5),'66735f')
    for side in (-12,12):
        s.box(room,'SideWall'+str(side),(side,3.5,-21),(.5,7,42),'66735f')
    for side in (-7.5,7.5):
        s.box(room,'FrontWall'+str(side),(side,3.5,0),(9,7,.5),'738264')
        s.box(room,'FrontWindow'+str(side),(side,2.8,.27),(6,2.7,.1),'637b70',False)
    s.box(room,'DoorHeader',(0,5.8,0),(6,2.4,.5),'738264')
    lock=s.node('Lock','Node3D',room)
    s.box(lock,'SecurityDoor',(0,2.5,0),(6,5,.6),'243b40')
    s.text(lock,'LockedText',(0,2.5,.4),'DEFEAT THE PREVIOUS BOSS\nTO UNLOCK THIS STORE',24,color)
    sign(room,'ShopSign',(0,7.8,.2),24,title,color,48)
    s.poster(room,'WallPoster',(11.7,2.7,-8),tier,3.0,-90)
    s.text(room,'BossBanner',(0,5,-41.6),['','FOREMAN TUSK','MADAM MAGPIE','MECHA DRAGON'][tier],45,color)
    for aisle,ax in enumerate((-7,0,7)):
        s.box(room,'Shelf'+str(aisle),(ax,.8,-12),(2,1.6,9),'857354')
        for j in range(4):
            local=(ax,1.75,-15+j*2)
            actual=(x+local[0],local[1],z+local[2]) if orientation==0 else (x-local[0],local[1],z-local[2])
            stock(actual, 'canned_food' if tier==2 else 'stolen_goods')
    for dz in (-7,-24,-35):
        for ax in (-7,7):
            s.box(room,'Tube%s%s'%(ax,dz),(ax,6.65,dz),(3,.12,.35),color,False,True)
            s.light(room,'Light%s%s'%(ax,dz),(ax,6.1,dz),color,2.5,16)
    for side in (-9,9):
        barrel(room,'BossCover'+str(side),(side,.8,-34))
    s.box(room,'ArenaStripe',(0,.025,-25),(22,.025,.2),color,False)
    # One glowing hero accent per store, on the back wall, so each shop reads
    # as its own brand from the street. Non-solid, deterministic.
    if tier==1:
        s.cyl(room,'WrenchShaft',(0,3.4,-41.2),.35,3.2,'steel',(0,0,90))
        s.cyl(room,'WrenchHead',(1.8,3.4,-41.2),.8,.7,'gold',glow=True)
        s.light(room,'WrenchGlow',(0,3.2,-40.6),'amber_hot',1.6,8)
    elif tier==2:
        s.box(room,'Birdhouse',(9,4.6,-41.2),(1.2,1.4,1.2),'wood_warm',False,rotation=(0,0,8))
        s.box(room,'BirdhouseRoof',(9,5.5,-41.2),(1.6,.25,1.6),'awning_red',False,rotation=(0,0,8))
        s.cyl(room,'BirdhouseHole',(9,4.7,-40.55),.22,.1,'neon_teal',(90,0,0),True)
        s.light(room,'SeedGlow',(9,4.6,-40.2),'neon_teal',1.4,7)
    else:
        s.box(room,'ServerRack',(0,1.4,-41.1),(3,2.8,1),'plum_panel',False)
        for j in range(6):
            s.box(room,'RackLight'+str(j),(-1+j*.4,2.2,-40.55),(.24,.1,.06),('neon_teal','neon_pink')[j%2],False,True)
        s.light(room,'RackGlow',(0,1.6,-40.2),'turquoise_light',1.5,8)
# Illustrated store branding from the generated poster atlas.
s.poster(store,'WallPoster',(-16.7,2.7,-23.8),0,3.0,90)
for i,px in enumerate((-11.4,-3.8,3.8,11.4)):
    s.poster(base,'TargetPoster'+str(i),(px,-9.4,21.3),i,2.4)
# Skyline and broad yard give the road a grounded silhouette.
for i in range(12):
    sx=-65+i*15
    s.box(road,'Skyline'+str(i),(sx,8+(i%3)*3,-96),(11,16+(i%3)*6,12),'344548')
s.box(road,'OuterGround',(20,-1.3,-4),(185,1,180),'293a39')

# ---------------------------------------------------------------------------
# Rat Mart dressing pass. Everything here is non-solid garnish: signage,
# awning scallops, cone lamps, wall trim, goods displays, the boss kitchen
# and distillery glow. Collision geometry above is final; this block never
# touches a solid box, a marker name or a stock spawn.
# ---------------------------------------------------------------------------

# Exterior hero sign: cheese bulbs under the big board, one bulb flickered dark.
for i,x in enumerate((-2,0,2)):
    s.cyl(store,'SignSocket'+str(i),(x,5.85,-21.8),.09,.2,'steel_dark')
    s.sphere(store,'SignBulb'+str(i),(x,5.55,-21.8),(.22,.26,.22),'cheese_yellow',i!=1)
# Blade sign for street traffic coming from the east.
s.box(store,'BladeSign',(-17.15,4.2,-27),(.25,2.9,1),'plum_panel',False)
s.text(store,'BladeSignTop',(-16.9,4.95,-27),'FINE',26,'cream',90)
s.text(store,'BladeSignBottom',(-16.9,3.7,-27),'GOODS',26,'neon_pink',90)
s.sphere(store,'BladeSignDot',(-17.15,5.8,-27),(.12,.12,.12),'neon_pink',True)
# Window mullions, sills and the pink neon tube in the doorway.
for wx in (-10,10):
    for mx in (-2.7,0,2.7):
        s.box(store,'Mullion%s%s'%(wx,mx),(wx+mx,2.9,-21.66),(.1,2.4,.16),'wood_warm',False)
    s.box(store,'WindowSill'+str(wx),(wx,1.52,-21.68),(8,.14,.22),'cheese_rind',False)
s.box(store,'DoorNeon',(0,4.0,-21.6),(4.5,.09,.09),'neon_pink',False,True)
for x in (-2.3,2.3):
    s.box(store,'DoorNeonSide'+str(x),(x,3.2,-21.6),(.09,1.6,.09),'neon_pink',False,True)
# Interior trim: teal wainscot band and cream crown line on every wall.
for x in (-16.7,16.7):
    s.box(store,'Wainscot'+str(x),(x,.7,-43),(.08,.4,40),'turquoise_deep',False)
    s.box(store,'CrownLine'+str(x),(x,4.7,-43),(.08,.14,40),'cream',False)
for wx in (-10,10):
    s.box(store,'FrontWainscot'+str(wx),(wx,.7,-21.77),(14,.4,.08),'turquoise_deep',False)
# Six hanging cone lamps, one above every shop light.
for lx,lz in [(-8,-30),(8,-30),(-8,-42),(8,-42),(-8,-55),(8,-55)]:
    s.cyl(store,'LampCord%s%s'%(lx,lz),(lx,5.5,lz),.03,.55,'steel_dark')
    s.cyl(store,'LampCone%s%s'%(lx,lz),(lx,5.08,lz),.5,.42,'plum_panel')
    s.sphere(store,'LampBulb%s%s'%(lx,lz),(lx,4.86,lz),(.16,.2,.16),'amber_hot',True)
# Crooked hanging aisle boards break up the flat ceiling line and give the
# floor plan readable landmarks. All positions are fixed - no rng here.
for hi,(hx,hz,label,yaw) in enumerate([(-3,-33,'AISLE 01',-8),(4,-37,'AISLE 02',10),(-1,-47,'FRESH-ish',-5)]):
    s.cyl(store,'SignCable%s'%(hi),(hx,5.85,hz),.02,.55,'steel_dark')
    s.box(store,'HangingSign%s'%(hi),(hx,5.4,hz),(1.5,.55,.06),'plum_panel',False,rotation=(0,yaw,2 if hi==1 else -3))
    s.text(store,'HangingText%s'%(hi),(hx,5.4,hz-.05),label,13,'cream',yaw)
# Idle ceiling fan over the customer area: rod, hub and two crossed blades.
s.cyl(store,'FanRod',(3,5.9,-26),.04,.65,'steel_dark')
s.box(store,'FanHub',(3,5.5,-26),(.3,.12,.3),'steel_dark',False)
s.box(store,'FanBladeA',(3,5.5,-26),(2.5,.04,.24),'wood_dark',False,rotation=(0,8,0))
s.box(store,'FanBladeB',(3,5.5,-26),(2.5,.04,.24),'wood_dark',False,rotation=(0,98,3))
# Turquoise service pipe with gold valves along the back partition.
s.cyl(store,'ServicePipe',(-4,3.5,-50.7),.13,23,'turquoise_deep',(90,0,0))
for vx in (-12,-7,-2):
    s.cyl(store,'ValveStem'+str(vx),(vx,3.5,-50.62),.05,.14,'gold')
    s.cyl(store,'ValveWheel'+str(vx),(vx,3.5,-50.55),.3,.07,'gold',(90,0,0))
# Cut cheese-wheel display just inside the door.
s.cyl(store,'CheeseWheel',(-5,.35,-24.5),1.05,.7,'cheese_yellow')
s.cyl(store,'CheeseWheelTop',(-5,.95,-24.5),.75,.5,'cheese_pale')
s.box(store,'CheeseWedge',(-4.55,.3,-23.75),(.7,.4,.6),'cheese_rind',False,rotation=(0,25,0))
s.text(store,'CheesePrice',(-5,2,-24.5),'WHOLE WHEEL / 12 COIN',16,'cream_dim')
# Backlit moonshine wall display beside the checkout.
s.box(store,'MoonshineGlowPanel',(16.7,2,-35),(.06,2.4,4.4),'moonshine_purple',False,True)
for sy in (1.5,2.6):
    s.box(store,'BottleShelf'+str(sy),(16.45,sy,-35),(.9,.08,4.4),'wood_warm',False)
    for j in range(5):
        s.cyl(store,'Bottle%s%s'%(sy,j),(16.45,sy+.25,-33-j*.85),.11,.42,'moonshine_pink' if j%2 else 'moonshine_purple')
s.light(store,'MoonshineLight',(15.8,2.4,-35),'moonshine_pink',.9,4)
# Fridge shelves and canned goods seen through the glass.
for i,z in enumerate((-40,-45)):
    for sy in (1.3,2.1):
        s.box(store,'FridgeShelf%s%s'%(i,sy),(13.2,sy,z),(.06,.05,2.9),'steel',False)
        for j in range(4):
            s.cyl(store,'FridgeCan%s%s%s'%(i,sy,j),(13.2,sy+.2,z-1.2+j*.8),.1,.3,('steel','turquoise','cheese_pale','steel')[j])
# Stockroom clutter: crates, buckets and handwritten price tags.
for ci,(cx,cy,cz,rot) in enumerate([(-14,.55,-53,0),(-12.7,.55,-53,10),(-13.4,1.65,-53.3,15),(-13.4,.55,-53.9,-6)]):
    s.box(store,'Crate'+str(ci),(cx,cy,cz),(1.1,1.1,1.1),'wood_warm',False,rotation=(0,rot,0))
for bi,bz in enumerate((-56.5,-57.2)):
    s.cyl(store,'Bucket'+str(bi),(6.4+bi*.8,.2,bz),.26,.4,'steel')
s.text(store,'TagCheese',(-10,2.6,-28.2),'99 COIN',15,'cheese_yellow')
s.text(store,'TagDeal',(4,2.6,-28.2),'2 FOR 1',15,'cheese_yellow')
# Six more illustrated posters around the shop.
for pi,(px,py,pz,kind,yaw) in enumerate([(-16.68,3,-30,0,90),(16.68,3,-33,2,-90),
        (-16.68,3,-44,1,90),(16.68,3,-47,3,-90),(-8,2.3,-50.78,0,0),(-4,2.3,-50.78,2,0)]):
    s.poster(store,'ExtraPoster'+str(pi),(px,py,pz),kind,2.2,yaw)
# Aisle end-caps: plum panels with a glowing cheese stripe.
for aisle,x in enumerate((-10,-3,4)):
    for ez in (-35.7,-45.7):
        s.box(store,'EndCap%s%s'%(aisle,ez),(x,1.15,ez),(2.4,2.3,.12),'plum_panel',False)
        s.box(store,'EndCapStripe%s%s'%(aisle,ez),(x,2.1,ez),(2.4,.2,.14),'cheese_yellow',False,True)
        s.text(store,'EndCapLabel%s%s'%(aisle,ez),(x,2.62,ez-.08),('CHEESE','SPIRITS','TINS')[aisle],15,'cream')
# Worn walk-path stripes guiding customers to the arena.
for pz in range(-24,-60,-3):
    s.box(store,'PathStripe'+str(pz),(.5,.015,pz),(3,.018,1.4),'cream_dim',False,rotation=(0,.6 if pz%2 else -.4,0))
# Crooked maintenance details: sagging patch, crooked duct, riveted plate.
s.box(store,'SagPatch',(3,5.8,-37),(2.6,.12,1.7),'wood_dark',False,rotation=(0,0,7))
s.box(store,'CrookDuct',(-12,5.35,-48),(3.2,.45,.5),'steel',False,rotation=(0,5,2))
s.box(store,'RivetPlate',(-16.68,2.2,-36),(1.6,1.2,.06),'steel',False,rotation=(0,90,0))
# Sidewalk merchandising: sandwich board and a crate stack by the door.
s.box(store,'BoardLeft',(3.6,.8,-18.9),(1,1.6,.07),'awning_cream',False,rotation=(0,-10,8))
s.box(store,'BoardRight',(3.6,.8,-19.1),(1,1.6,.07),'awning_cream',False,rotation=(0,-10,-8))
s.text(store,'BoardText',(3.55,1.05,-18.7),'FRESH-ish\nCHEESE',13,'plum_ink',-10)
for ci,(cx,cy,cz,rot) in enumerate([(-6.2,.55,-18.6,0),(-6,1.7,-18.7,12),(-5,.45,-19,-8)]):
    s.box(store,'WalkCrate'+str(ci),(cx,cy,cz),(1.1,1.1,1.1),'wood_warm',False,rotation=(0,rot,0))
# Scalloped awning skirt and crooked support poles.
for sx in range(-15,16,3):
    s.box(store,'AwningScallop'+str(sx),(sx,4.14,-18.4),(2.6,.14,.5),'awning_red' if sx%2 else 'awning_cream',False,rotation=(6,0,2 if sx%2 else -2))
for px in (-14,14):
    s.cyl(store,'AwningPole'+str(px),(px,2.1,-18.3),.07,4.4,'steel_dark')

# Boss kitchen: countertop, stock pot, pot rack, stove wall and the vault door.
s.box(store,'KitchenCounter',(0,2.08,-76),(7.6,.16,2.9),'steel',False)
s.box(store,'CuttingBoard',(1.8,2.24,-76.3),(1.3,.09,.9),'wood_warm',False,rotation=(0,18,0))
s.box(store,'BoardCheese',(1.8,2.45,-76.3),(.5,.32,.5),'cheese_yellow',False,rotation=(0,18,0))
s.cyl(store,'StockPot',(-2.3,2.9,-76.4),1.25,1.5,'steel')
s.cyl(store,'PotLid',(-2.3,3.7,-76.4),1.32,.12,'steel_dark')
s.sphere(store,'LidKnob',(-2.3,3.82,-76.4),(.1,.12,.1),'gold')
s.cyl(store,'LadleHandle',(-2.85,3.4,-76.1),.05,1.3,'steel',(0,0,24))
s.sphere(store,'LadleScoop',(-3.25,2.85,-76.1),(.18,.22,.18),'steel')
s.box(store,'PotRackBar',(0,4.2,-76),(5,.12,.12),'steel_dark',False)
for hx in (-1.5,0,1.5):
    s.cyl(store,'PotChain'+str(hx),(hx,3.95,-76),.03,.42,'steel_dark',False)
    s.cyl(store,'HangingPot'+str(hx),(hx,3.55,-76),.4,.42,'steel_dark')
s.box(store,'StoveWall',(0,1.4,-79.6),(7,2.8,.25),'steel_dark',False)
for bx in (-2.4,-.8,.8,2.4):
    s.cyl(store,'Burner'+str(bx),(bx,.9,-79.45),.45,.08,'ember',glow=True)
    s.sphere(store,'Flame'+str(bx),(bx,1.08,-79.45),(.22,.35,.22),'amber_hot',True)
s.box(store,'StoveGrate',(0,2.5,-79.5),(7,.15,.4),'steel_dark',False)
s.box(store,'VaultFrame',(9,1.6,-79.85),(3.6,3.6,.15),'steel_dark',False)
s.cyl(store,'VaultDoor',(9,1.6,-79.7),1.5,.2,'gold',(90,0,0))
for ri in range(8):
    s.sphere(store,'VaultRivet'+str(ri),(9+1.28*(.707 if ri%2 else (1 if ri<4 else 0)),1.6+1.28*(.707 if ri%2 else (0 if ri<2 or ri>5 else 0)),-79.56),(.07,.07,.07),'steel_dark')
s.cyl(store,'VaultWheel',(9,1.6,-79.54),.4,.1,'steel_dark',(90,0,0))
for sa in (0,60,120):
    s.box(store,'VaultSpoke'+str(sa),(9,1.6,-79.5),(.08,.8,.07),'steel_dark',False,rotation=(0,0,sa))

# Distillery garnish: glow rings on the stills, bottle shelf, purple puddle,
# ceiling pipes with drip legs.
for x in (-9,-2,5):
    s.cyl(cellar,'ValveGlow'+str(x),(x,-9.3,-52.7),.52,.06,'neon_pink',(90,0,0),True)
    s.cyl(cellar,'StillBand'+str(x),(x,-10.6,-55),2.06,.28,'moonshine_purple',glow=True)
s.box(cellar,'BottleShelf',(0,-10.2,-62.4),(10,.1,.9),'wood_warm',False)
for j in range(7):
    s.cyl(cellar,'ReserveBottle'+str(j),(-4.5+j*1.5,-9.9,-62.4),.1,.4,'moonshine_pink' if j%2 else 'moonshine_purple',glow=True)
s.cyl(cellar,'Puddle',(3,-11.985,-47),1.5,.015,'moonshine_purple',glow=True)
s.cyl(cellar,'PuddleDrip',(4.3,-11.988,-46.3),.8,.012,'moonshine_purple',glow=True)
for px in (-6,6):
    s.cyl(cellar,'CellarPipe'+str(px),(px,-6,-51),.18,22,'steel_dark',(90,0,0))
    for dz in (-41.5,-60.5):
        s.cyl(cellar,'PipeLeg%s%s'%(px,dz),(px,-6.6,dz),.12,1.4,'steel_dark')

# Hideout garnish: pegboard of tools behind the machines and a lounge pad.
s.box(base,'ToolBoard',(5,-9.5,44.7),(5,2.4,.08),'plum_panel',False)
for ti,(tx,tw,th) in enumerate([(-1.6,.3,1.1),(0,.25,.8),(1.4,1.0,.22)]):
    s.box(base,'PegTool'+str(ti),(5+tx,-9.3-th*.2,44.62),(tw,th,.07),'steel',False)
s.box(base,'LoungePad',(-12,-11.7,42),(2.4,.35,1.3),'turquoise_deep',False)
s.box(base,'LoungeBack',(-12,-11.3,42.7),(2.4,.8,.3),'turquoise_deep',False)

# Preview camera is replaced automatically when a local player spawns.
s.node('LobbyPreview','Camera3D','.', 'position = Vector3(31, 22, 26)\nrotation_degrees = Vector3(-22, 30, 0)\ncurrent = true\nfov = 65.0')
s.save(Path('scenes/level/heist_world.tscn'),'[ext_resource type="Script" path="res://scripts/level/heist_world.gd" id="world"]\n[ext_resource type="Texture2D" path="res://assets/environment/heist/shop_posters.png" id="posters"]\n')

# Physics merchandise scenes, registered with the existing MultiplayerSpawner.
for item,color,shape in [('rotten_cheese','c5ce69','cheese'),('moonshine','899d70','bottle'),('canned_food','9aa3ab','can'),('stolen_goods','d5b565','box')]:
    t=Scene()
    t.node(item.title().replace('_',''),'RigidBody3D',props='collision_layer = 4\ncollision_mask = 31\nlinear_damp = 1.0\nangular_damp = 1.0\nscript = ExtResource("item")\nitem_id = "%s"'%item)
    if shape in ('bottle','can'):
        t.cyl('.','Product',(0,.3,0),.22,.6,color)
        t.cyl('.','Label',(0,.3,0),.225,.25,'d7cfab')
        if shape=='bottle':
            t.cyl('.','Neck',(0,.7,0),.09,.25,color)
            t.cyl('.','Cork',(0,.84,0),.1,.08,'8e6541')
    else:
        t.box('.','Product',(0,.2,0),(.65,.4,.5),color,False)
        if shape=='cheese':
            for i,(x,z) in enumerate(((-.2,0),(.1,.13),(.15,-.15))):
                t.cyl('.','Mould'+str(i),(x,.408,z),.07,.01,'7d9348')
    collision=t.resource('BoxShape3D','size = Vector3(0.65, 0.8, 0.5)')
    t.node('Collision','CollisionShape3D','.', 'position = Vector3(0, 0.4, 0)\nshape = '+collision)
    config=t.resource('SceneReplicationConfig','properties/0/path = NodePath(".:position")\nproperties/0/spawn = true\nproperties/0/replication_mode = 2\nproperties/1/path = NodePath(".:rotation")\nproperties/1/spawn = true\nproperties/1/replication_mode = 2\nproperties/2/path = NodePath(".:carried_by")\nproperties/2/spawn = true\nproperties/2/replication_mode = 2')
    t.node('MultiplayerSynchronizer','MultiplayerSynchronizer','.', 'replication_config = '+config)
    folder=ROOT/'scenes/items/heist'
    folder.mkdir(parents=True,exist_ok=True)
    t.save(Path('scenes/items/heist')/(item+'.tscn'),'[ext_resource type="Script" path="res://scripts/items/item_rigid_body_3d.gd" id="item"]\n')
print('Built editable heist world and four multiplayer merchandise scenes. nodes: %d' % len(s.nodes))
