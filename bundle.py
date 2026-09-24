# -*- coding: utf-8 -*-
"""
Universal Bundler Pipeline for TSB Framework (bundle.py)
Compiles all modular src/ files into a standalone, robust, production-grade tsb.lua
with Lua virtual module resolution.
"""

import os
import re

BASE_DIR = os.getcwd()
SRC_DIR = os.path.join(BASE_DIR, "src")

modules = {}

# Recursively read all .luau and .lua files in src/
for root, _, files in os.walk(SRC_DIR):
    for f in files:
        if f.endswith(".luau") or f.endswith(".lua"):
            full_path = os.path.join(root, f)
            rel_path = os.path.relpath(full_path, SRC_DIR).replace("\\", "/")
            mod_name = os.path.splitext(rel_path)[0]
            with open(full_path, "r", encoding="utf-8") as src_f:
                modules[mod_name] = src_f.read()

print(f"Bundling {len(modules)} modules from src/...")

# Generate the Virtual Module Loader
bundle_header = """-- // ========================================================================================
-- // ⚡ 4080 CUSTOM HUB v8.0 - PRODUCTION EXPERT / SPECIALIST FRAMEWORK
-- // Architecture: Modular Luau Service Architecture + IoC Container + FSM & Telemetry
-- // Built by Universal Bundler Pipeline
-- // ========================================================================================

local __modules = {}
local __cache = {}

local function require(modName)
    local normalized = modName:gsub("%.luau$", ""):gsub("%.lua$", ""):gsub("^src/", "")
    normalized = normalized:gsub("/", ".")
    
    -- Exact or normalized match
    local modFunc = __modules[normalized] or __modules[modName] or __modules[normalized:gsub("%.", "/")]
    if not modFunc then
        for k, v in pairs(__modules) do
            if k:lower() == normalized:lower() or k:lower() == modName:lower() then
                modFunc = v
                normalized = k
                break
            end
        end
    end

    if not modFunc then
        error(string.format("[Bundler] Module '%s' not found!", tostring(modName)))
    end

    if not __cache[normalized] then
        __cache[normalized] = modFunc()
    end
    return __cache[normalized]
end
"""

bundle_body = ""
for mod_name, mod_content in modules.items():
    clean_name = mod_name.replace("/", ".")
    bundle_body += f'\n-- Module: {clean_name}\n__modules["{clean_name}"] = function()\n{mod_content}\nend\n'
    if "/" in mod_name:
        bundle_body += f'__modules["{mod_name}"] = __modules["{clean_name}"]\n'

bundle_footer = """
-- ============================================================================
-- FRAMEWORK ENTRYPOINT
-- ============================================================================
local Bootstrap = require("Bootstrap")
Bootstrap:Init()

print("[4080 HUB v8.0] Production Framework Booted Successfully.")
"""

full_bundle = bundle_header + bundle_body + bundle_footer

target_path = os.path.join(BASE_DIR, "tsb.lua")
with open(target_path, "w", encoding="utf-8") as f:
    f.write(full_bundle)

print(f"Bundled successfully into {target_path}!")
print(f"Total lines: {len(full_bundle.splitlines())} | Total size: {len(full_bundle.encode('utf-8'))} bytes")
