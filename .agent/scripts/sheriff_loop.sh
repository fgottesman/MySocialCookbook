#!/bin/bash

# 🤠 Sheriff Agent Loop
# Runs the Sheriff Agent audit every 15 minutes.

echo "🤠 Sheriff: Starting the 15-minute patrol..."

while true; do
  echo "🤠 Sheriff: Checking the trails at $(date)"
  
  # Run the sheriff agent
  npx tsx .agent/scripts/sheriff_agent.ts
  
  echo "🤠 Sheriff: Patrol finished. Sleeping for 15 minutes..."
  sleep 900
done
