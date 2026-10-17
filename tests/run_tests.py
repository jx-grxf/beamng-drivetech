"""Runs the DriveTech Lua tests inside LuaJIT 2.1 (the Lua version BeamNG uses).

    pip install lupa
    python tests/run_tests.py
"""
import os
import sys

from lupa import luajit21

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
mod_root = os.path.join(root, "mod").replace("\\", "/")
tests_dir = os.path.join(root, "tests").replace("\\", "/")

lua = luajit21.LuaRuntime(unpack_returned_tuples=True)
lua.execute(f'package.path = "{mod_root}/lua/vehicle/?.lua;{tests_dir}/?.lua;" .. package.path')
lua.globals().MOD_ROOT = mod_root
failed = lua.execute(f'return dofile("{tests_dir}/test_drivetech.lua")')
sys.exit(1 if failed else 0)
