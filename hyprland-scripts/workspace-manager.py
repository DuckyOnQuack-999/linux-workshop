#!/usr/bin/env python3
import subprocess
import json
import sys
import argparse

def get_workspaces():
    """Get all workspaces from Hyprland"""
    try:
        cmd = "hyprctl workspaces -j"
        result = subprocess.run(cmd.split(), capture_output=True, text=True, check=True)
        return json.loads(result.stdout)
    except subprocess.CalledProcessError as e:
        print(f"Error getting workspaces: {e}")
        return []
    except json.JSONDecodeError as e:
        print(f"Error parsing workspaces: {e}")
        return []

def create_workspace(name):
    """Create a new workspace with given name"""
    try:
        cmd = f"hyprctl dispatch workspace name:{name}"
        subprocess.run(cmd.split(), check=True)
        print(f"Created workspace: {name}")
    except subprocess.CalledProcessError as e:
        print(f"Error creating workspace: {e}")

def list_workspaces():
    """List all workspaces"""
    workspaces = get_workspaces()
    if not workspaces:
        print("No workspaces found")
        return
    
    print("Active Workspaces:")
    for ws in workspaces:
        print(f"  {ws['id']}: {ws.get('name', 'Unnamed')} ({ws['windows']} windows)")

def main():
    parser = argparse.ArgumentParser(description="Hyprland Workspace Manager")
    parser.add_argument("action", choices=["list", "create"], help="Action to perform")
    parser.add_argument("--name", help="Workspace name for create action")
    
    args = parser.parse_args()
    
    if args.action == "list":
        list_workspaces()
    elif args.action == "create":
        if not args.name:
            print("Error: --name required for create action")
            sys.exit(1)
        create_workspace(args.name)

if __name__ == "__main__":
    main()
