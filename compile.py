import os
import subprocess
import shutil

# Paths config
XCODE_13_PATH = "/Applications/Xcode-13.4.1.app"
CLANG_PATH = f"{XCODE_13_PATH}/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang"
SDK_PATH = f"{XCODE_13_PATH}/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk"

SRC_DIR = "src"
BUILD_DIR = "build_output"
APP_NAME = "ChineseApp"
APP_BUNDLE = f"{BUILD_DIR}/{APP_NAME}.app"

# Header search paths
INCLUDE_PATHS = [
    "src",
    "src/Core",
    "src/Models",
    "src/Views",
    "src/Controllers"
]

def clean_and_prepare():
    if os.path.exists(BUILD_DIR):
        shutil.rmtree(BUILD_DIR)
    os.makedirs(BUILD_DIR)
    os.makedirs(APP_BUNDLE)

def compile_source_files():
    # Gather all .m files
    source_files = []
    for root, dirs, files in os.walk(SRC_DIR):
        for file in files:
            if file.endswith(".m"):
                source_files.append(os.path.join(root, file))
    
    object_files = []
    include_args = []
    for path in INCLUDE_PATHS:
        include_args.extend(["-I", path])
        
    for src in source_files:
        obj_name = os.path.basename(src).replace(".m", ".o")
        obj_path = os.path.join(BUILD_DIR, obj_name)
        
        print(f"Compiling {src}...")
        cmd = [
            CLANG_PATH,
            "-x", "objective-c",
            "-target", "armv7-apple-ios9.0",
            "-isysroot", SDK_PATH,
            "-fobjc-arc",
            "-O2"
        ] + include_args + ["-c", src, "-o", obj_path]
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            print(f"Error compiling {src}:")
            print(result.stderr)
            exit(1)
        object_files.append(obj_path)
        
    return object_files

def link_binary(object_files):
    exec_path = f"{APP_BUNDLE}/{APP_NAME}"
    print(f"Linking binary to {exec_path}...")
    
    cmd = [
        CLANG_PATH,
        "-target", "armv7-apple-ios9.0",
        "-isysroot", SDK_PATH,
        "-fobjc-arc",
        "-framework", "UIKit",
        "-framework", "Foundation",
        "-framework", "AVFoundation",
        "-framework", "ImageIO",
        "-framework", "QuartzCore",
        "-framework", "CoreGraphics",
        "-framework", "Security"
    ] + object_files + ["-o", exec_path]
    
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print("Error linking binary:")
        print(result.stderr)
        exit(1)
    print("Linking succeeded!")

def package_app():
    print("Packaging resources into .app bundle...")
    # Copy Info.plist
    shutil.copy("src/Info.plist", f"{APP_BUNDLE}/Info.plist")
    
    # Copy Textbooks directory
    if os.path.exists("Textbooks"):
        shutil.copytree("Textbooks", f"{APP_BUNDLE}/Textbooks")
        
    # Copy ChineseWordmp3 directory
    if os.path.exists("ChineseWordmp3"):
        shutil.copytree("ChineseWordmp3", f"{APP_BUNDLE}/ChineseWordmp3")
        
    print(f"Success! Bundle created at: {os.path.abspath(APP_BUNDLE)}")

def package_ipa():
    print("Packaging .app into .ipa for Sideloadly...")
    payload_dir = os.path.join(BUILD_DIR, "Payload")
    if os.path.exists(payload_dir):
        shutil.rmtree(payload_dir)
    os.makedirs(payload_dir)
    shutil.copytree(APP_BUNDLE, os.path.join(payload_dir, f"{APP_NAME}.app"))
    
    ipa_path = os.path.join(BUILD_DIR, f"{APP_NAME}.ipa")
    if os.path.exists(ipa_path):
        os.remove(ipa_path)
        
    shutil.make_archive(os.path.join(BUILD_DIR, APP_NAME), 'zip', BUILD_DIR, "Payload")
    os.rename(os.path.join(BUILD_DIR, f"{APP_NAME}.zip"), ipa_path)
    shutil.rmtree(payload_dir)
    print(f"Success! IPA created at: {os.path.abspath(ipa_path)}")

if __name__ == "__main__":
    if not os.path.exists(CLANG_PATH) or not os.path.exists(SDK_PATH):
        print(f"Error: Xcode 13 toolchain or SDK not found. Please verify {XCODE_13_PATH} exists.")
        exit(1)
        
    clean_and_prepare()
    object_files = compile_source_files()
    link_binary(object_files)
    package_app()
    package_ipa()

