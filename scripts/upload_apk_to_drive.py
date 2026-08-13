#!/usr/bin/env python3
"""Upload the verified debug APK to the configured Google Drive folder."""
import json
import sys
from pathlib import Path

from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

APK_PATH = Path(sys.argv[1])
TOKEN_PATH = Path("/home/yun/.config/gogcli/drive_token.json")
CLIENT_PATH = Path("/home/yun/.config/gogcli/credentials.json")
FOLDER_ID = "1oVjqIscRcDa92Yfk1L_k280rRgslL4Oo"
SCOPES = ["https://www.googleapis.com/auth/drive"]

if not APK_PATH.is_file():
    raise SystemExit(f"APK not found: {APK_PATH}")

with TOKEN_PATH.open(encoding="utf-8") as token_file:
    token = json.load(token_file)
with CLIENT_PATH.open(encoding="utf-8") as client_file:
    client_data = json.load(client_file)
    client = client_data.get("installed", client_data)

credentials = Credentials(
    token=token.get("token", token.get("access_token")),
    refresh_token=token["refresh_token"],
    token_uri=token.get("token_uri", "https://oauth2.googleapis.com/token"),
    client_id=client["client_id"],
    client_secret=client["client_secret"],
    scopes=token.get("scopes", SCOPES),
)
drive = build("drive", "v3", credentials=credentials)
media = MediaFileUpload(
    str(APK_PATH),
    mimetype="application/vnd.android.package-archive",
    resumable=True,
    chunksize=10 * 1024 * 1024,
)
request = drive.files().create(
    body={"name": APK_PATH.name, "parents": [FOLDER_ID]},
    media_body=media,
    fields="id,name,size,webViewLink,webContentLink",
)
response = None
while response is None:
    status, response = request.next_chunk()
    if status:
        print(f"upload: {status.progress() * 100:.0f}%", flush=True)

drive.permissions().create(
    fileId=response["id"],
    body={"type": "anyone", "role": "reader"},
).execute()
info = drive.files().get(
    fileId=response["id"],
    fields="id,name,size,webViewLink,webContentLink,permissions",
).execute()
print(json.dumps({
    "id": info["id"],
    "name": info["name"],
    "size": info["size"],
    "view": info.get("webViewLink"),
    "download": info.get("webContentLink"),
}, ensure_ascii=False))
