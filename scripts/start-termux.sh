#!/usr/bin/env bash

# Exit on error
set -e

echo "Starting Termux setup for LearnHarness..."

# Check if we are running in Termux
if [ -n "$PREFIX" ] && [[ "$PREFIX" == *"com.termux"* ]]; then
  echo "Detected Termux environment."

  # Check if Node.js is installed
  if ! command -v node &> /dev/null; then
    echo "Node.js not found. Installing..."
    pkg update -y
    pkg install -y nodejs
  else
    echo "Node.js is already installed: $(node -v)"
  fi
else
  echo "Warning: Not running in Termux, skipping pkg installation."
  if ! command -v node &> /dev/null; then
    echo "Error: Node.js is required but not installed."
    exit 1
  fi
fi

# Move to the repository root
cd "$(dirname "$0")/.."

echo "Installing npm dependencies..."
npm install

echo "Building Next.js application..."
npm run build

echo "Starting local Next.js server on port 3000..."
npm run start
