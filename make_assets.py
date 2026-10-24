import os
import subprocess
from PIL import Image

EDGE_PATH = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
BASE_DIR = r"C:\Users\kashi\Downloads\CallVexa"

# 1. HTML for 1024x1024 App Icon
icon_html = """<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    width: 1024px;
    height: 1024px;
    background: #0a0f1e;
    display: flex;
    align-items: center;
    justify-content: center;
    overflow: hidden;
  }
  .card {
    width: 820px;
    height: 820px;
    background: radial-gradient(circle at 30% 30%, #152238 0%, #0d1527 100%);
    border: 32px solid #2f6bff;
    border-radius: 200px;
    display: flex;
    align-items: center;
    justify-content: center;
    box-shadow: 0 40px 100px rgba(47, 107, 255, 0.35);
  }
  svg {
    width: 480px;
    height: 480px;
  }
</style>
</head>
<body>
  <div class="card">
    <svg viewBox="0 0 64 64" fill="none" xmlns="http://www.w3.org/2000/svg">
      <path d="M20 16c-2 0-3.5 1.2-4 3-1.5 5.5 1 14 8 21s15.5 9.5 21 8c1.8-.5 3-2 3-4v-4c0-1.5-1-2.7-2.4-3.1l-4.8-1.4c-1.3-.4-2.7.1-3.4 1.2l-1.6 2.4c-3.2-1.8-6-4.6-7.8-7.8l2.4-1.6c1.1-.7 1.6-2.1 1.2-3.4L30.2 22c-.4-1.4-1.6-2.4-3.1-2.4H20z" fill="#2f6bff"/>
    </svg>
  </div>
</body>
</html>"""

# 2. HTML for 2732x2732 Splash Screen
splash_html = """<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    width: 2732px;
    height: 2732px;
    background: #0a0f1e;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    overflow: hidden;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
  }
  .card {
    width: 600px;
    height: 600px;
    background: radial-gradient(circle at 30% 30%, #152238 0%, #0d1527 100%);
    border: 24px solid #2f6bff;
    border-radius: 140px;
    display: flex;
    align-items: center;
    justify-content: center;
    box-shadow: 0 40px 120px rgba(47, 107, 255, 0.45);
    margin-bottom: 70px;
  }
  svg {
    width: 340px;
    height: 340px;
  }
  .title {
    font-size: 110px;
    font-weight: 800;
    color: #ffffff;
    letter-spacing: -2px;
    margin-bottom: 24px;
  }
  .subtitle {
    font-size: 46px;
    font-weight: 500;
    color: #7d8ea8;
    letter-spacing: 0.5px;
  }
</style>
</head>
<body>
  <div class="card">
    <svg viewBox="0 0 64 64" fill="none" xmlns="http://www.w3.org/2000/svg">
      <path d="M20 16c-2 0-3.5 1.2-4 3-1.5 5.5 1 14 8 21s15.5 9.5 21 8c1.8-.5 3-2 3-4v-4c0-1.5-1-2.7-2.4-3.1l-4.8-1.4c-1.3-.4-2.7.1-3.4 1.2l-1.6 2.4c-3.2-1.8-6-4.6-7.8-7.8l2.4-1.6c1.1-.7 1.6-2.1 1.2-3.4L30.2 22c-.4-1.4-1.6-2.4-3.1-2.4H20z" fill="#2f6bff"/>
    </svg>
  </div>
  <div class="title">CallVexa</div>
  <div class="subtitle">Cloud Call Center Platform</div>
</body>
</html>"""

def render():
    with open(os.path.join(BASE_DIR, "icon_temp.html"), "w", encoding="utf-8") as f:
        f.write(icon_html)
    with open(os.path.join(BASE_DIR, "splash_temp.html"), "w", encoding="utf-8") as f:
        f.write(splash_html)

    # Render Icon
    icon_out = os.path.join(BASE_DIR, "icon_raw.png")
    subprocess.run([
        EDGE_PATH,
        "--headless",
        "--disable-gpu",
        f"--window-size=1024,1024",
        f"--screenshot={icon_out}",
        f"file:///{os.path.join(BASE_DIR, 'icon_temp.html').replace(os.sep, '/')}"
    ], check=True)

    # Render Splash
    splash_out = os.path.join(BASE_DIR, "splash_raw.png")
    subprocess.run([
        EDGE_PATH,
        "--headless",
        "--disable-gpu",
        f"--window-size=2732,2732",
        f"--screenshot={splash_out}",
        f"file:///{os.path.join(BASE_DIR, 'splash_temp.html').replace(os.sep, '/')}"
    ], check=True)

    # Save to AppIcon
    app_icon_dst = os.path.join(BASE_DIR, "ios", "App", "App", "Assets.xcassets", "AppIcon.appiconset", "AppIcon-512@2x.png")
    img_icon = Image.open(icon_out).convert("RGBA").resize((1024, 1024), Image.LANCZOS)
    img_icon.save(app_icon_dst, format="PNG")
    print(f"Saved {app_icon_dst}")

    # Save to Splash
    splash_dir = os.path.join(BASE_DIR, "ios", "App", "App", "Assets.xcassets", "Splash.imageset")
    img_splash = Image.open(splash_out).convert("RGBA").resize((2732, 2732), Image.LANCZOS)
    for name in ["splash-2732x2732.png", "splash-2732x2732-1.png", "splash-2732x2732-2.png"]:
        dst = os.path.join(splash_dir, name)
        img_splash.save(dst, format="PNG")
        print(f"Saved {dst}")

    # Cleanup temp files
    os.remove(os.path.join(BASE_DIR, "icon_temp.html"))
    os.remove(os.path.join(BASE_DIR, "splash_temp.html"))
    os.remove(icon_out)
    os.remove(splash_out)
    print("Asset generation complete!")

if __name__ == "__main__":
    render()
