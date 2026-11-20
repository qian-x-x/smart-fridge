"""Export the openable shell from the Blender scene loaded in background mode."""

from pathlib import Path
import sys

import bpy
from mathutils import Vector


OUTPUT = (
    Path(__file__).resolve().parents[1]
    / "apps/fridge-app/web/fridge3d/assets/fridge-scene.glb"
)


def cut_compartments():
    objects = bpy.context.scene.objects
    body = objects["Fridge_Body"]
    gasket = objects["Door_Gasket"]
    # Blender coordinates are X across, Y toward the back and Z up, in metres.
    for panel_name in ("Door_Upper_L", "Drawer_Middle", "Drawer_Bottom"):
        panel = objects[panel_name]
        bounds = [panel.matrix_world @ Vector(corner) for corner in panel.bound_box]
        bottom = min(point.z for point in bounds) + 0.007
        top = max(point.z for point in bounds) - 0.007
        # Start inside the back wall and extend past the gasket at the front.
        back, front = -0.037, -0.73
        bpy.ops.mesh.primitive_cube_add(
            size=1, location=(0, (back + front) / 2, (bottom + top) / 2)
        )
        cutter = bpy.context.object
        cutter.dimensions = (0.90, back - front, top - bottom)
        bpy.context.view_layer.update()
        for target in (body, gasket):
            bpy.context.view_layer.objects.active = target
            modifier = target.modifiers.new("Storage opening", "BOOLEAN")
            modifier.operation = "DIFFERENCE"
            modifier.solver = "EXACT"
            modifier.object = cutter
            bpy.ops.object.modifier_apply(modifier=modifier.name)
        bpy.data.objects.remove(cutter, do_unlink=True)


def export(output):
    cut_compartments()
    # The handle booleans leave large planar faces beside curved bevels.
    # Keep their normals flat to avoid diagonal highlights after triangulation.
    for name in ("Door_Upper_L", "Door_Upper_R", "Drawer_Middle", "Drawer_Bottom"):
        for face in bpy.context.scene.objects[name].data.polygons:
            if abs(face.normal.y) > 0.9999:
                face.use_smooth = False
    steel = bpy.data.materials["Steel_Brushed"].node_tree
    # glTF uses the base roughness when the Blender noise graph is unavailable.
    for link in list(steel.nodes["Principled BSDF"].inputs["Roughness"].links):
        steel.links.remove(link)
    output.parent.mkdir(parents=True, exist_ok=True)
    result = bpy.ops.export_scene.gltf(
        filepath=str(output),
        export_format="GLB",
        export_animations=False,
        export_cameras=False,
        export_lights=False,
    )
    if result != {"FINISHED"}:
        raise RuntimeError(f"Failed to export {output}")


if __name__ == "__main__":
    arguments = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    export(Path(arguments[0]).resolve() if arguments else OUTPUT)
