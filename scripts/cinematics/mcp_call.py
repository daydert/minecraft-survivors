"""Call the configured local Blender MCP via real MCP stdio; save image replies."""
import argparse
import asyncio
import base64
import json
from pathlib import Path
import tomllib

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

ROOT = Path(__file__).resolve().parents[2]


async def run(args):
    cfg = tomllib.loads((ROOT / ".codex/config.toml").read_text())["mcp_servers"]["blender"]
    server = StdioServerParameters(command=cfg["command"], args=cfg.get("args", []),
                                  env=cfg.get("env"), cwd=str(ROOT))
    async with stdio_client(server) as streams:
        async with ClientSession(*streams) as session:
            info = await session.initialize()
            if args.tool == "list":
                result = await session.list_tools()
                output = {"server": info.serverInfo.model_dump(),
                          "tools": [t.model_dump(exclude_none=True) for t in result.tools]}
            else:
                params = json.loads(args.arguments)
                if args.code:
                    params["code"] = Path(args.code).read_text()
                result = await session.call_tool(args.tool, params)
                output = {"isError": result.isError, "content": []}
                for i, block in enumerate(result.content):
                    if block.type == "image":
                        out = Path(args.image or str(ROOT / "qa/cinematics/viewport.png"))
                        if i:
                            out = out.with_stem(out.stem + "_" + str(i))
                        out.parent.mkdir(parents=True, exist_ok=True)
                        out.write_bytes(base64.b64decode(block.data))
                        output["content"].append({"type": "image", "path": str(out)})
                    else:
                        output["content"].append(block.model_dump(exclude_none=True))
            if args.output:
                Path(args.output).write_text(json.dumps(output, ensure_ascii=False, indent=2) + "\n")
            print(json.dumps(output, ensure_ascii=False, indent=2))
            if output.get("isError"):
                raise SystemExit(1)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("tool")
    parser.add_argument("--arguments", default="{}")
    parser.add_argument("--code")
    parser.add_argument("--image")
    parser.add_argument("--output")
    asyncio.run(run(parser.parse_args()))
