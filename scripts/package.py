"""Build an installable plugin archive from an explicit, credential-free allowlist."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

root = Path(__file__).resolve().parents[1]
files = ["_meta.lua", "main.lua", "marketviewer.lua", "marketdata.lua", "graphwidget.lua", "polyapi.lua", "poly_config.lua.sample", "README.md"]
output = root / "dist" / "marketview.koplugin.zip"
output.parent.mkdir(exist_ok=True)
with ZipFile(output, "w", ZIP_DEFLATED) as archive:
    for name in files:
        archive.write(root / name, "marketview.koplugin/" + name)
with ZipFile(output) as archive:
    assert len(archive.namelist()) == len(files)
    assert not any(name.endswith("/poly_config.lua") for name in archive.namelist())
print(f"Built {output.name}: {len(files)} public files; private API configuration excluded.")
