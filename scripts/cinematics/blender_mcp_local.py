"""Project launcher for the audited, installed ahujasid MCP server. No downloads."""
import ipaddress
import os
import sys
import types

os.environ.update(DISABLE_TELEMETRY="true", BLENDERMCP_NO_UPDATE_CHECK="1",
                  BLENDER_HOST="127.0.0.1", BLENDER_PORT="9876",
                  BLENDER_MCP_APPS="0", BLENDER_MCP_OPENAI_FORMS="0")


def local_network_only(event, args):
    if event == "socket.getaddrinfo" and args[0] not in (None, "localhost", "127.0.0.1", "::1"):
        raise PermissionError("This project's Blender MCP only connects to localhost")
    if event == "socket.connect":
        address = args[1]
        if isinstance(address, tuple):
            host = address[0]
            if host != "localhost" and not ipaddress.ip_address(host).is_loopback:
                raise PermissionError("External connections are disabled for Blender MCP")


sys.addaudithook(local_network_only)

# Upstream's git checkout intentionally excludes config.py (telemetry credentials).
# Supply a disabled configuration; no credentials or external service are needed.
config = types.ModuleType("blender_mcp.config")
config.telemetry_config = types.SimpleNamespace(enabled=False)
sys.modules[config.__name__] = config

from blender_mcp import consent_prompt, server  # noqa: E402


async def no_collection_prompt(ctx):
    return ""


consent_prompt.maybe_prompt_for_consent = no_collection_prompt
server.maybe_prompt_for_consent = no_collection_prompt
server.premium_generation_guidance = lambda generators: ""
server.SERVER_INSTRUCTIONS = """Control the local Minecraft Survivors Blender scene.
Start with get_addon_status and get_scene_info. Stage and animate using
execute_blender_code, and inspect real viewport screenshots using look.
Keep connected block rigs and nearest sampled pixel textures. Save editable
.blend files. Final animation rendering runs ONLY in a separate headless
blender --background --python process; never render a movie through MCP.
External generators, asset libraries and telemetry are disabled.
Inspect actual bpy schemas and Blender 5.x layered Action slots."""
server.mcp._mcp_server.instructions = server.SERVER_INSTRUCTIONS
allowed = {"get_addon_status", "get_scene_info", "execute_blender_code", "look"}
for name in list(server.mcp._tool_manager._tools):
    if name not in allowed:
        server.mcp.remove_tool(name)
server.mcp._tool_manager._tools['get_addon_status'].description = (
    'Check the local Blender version, addon protocol and disabled integrations. '
    'Call once before scene editing. No account or external service is used.'
)
server.main()
