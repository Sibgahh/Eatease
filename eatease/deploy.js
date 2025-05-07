/**
 * Firebase Deployment Script for Order Update Fix
 * This script deploys both Firebase Functions and Firestore Security Rules
 */

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

// Configuration
const functionsDir = path.join(__dirname, 'functions');
const hasNodeModules = fs.existsSync(path.join(functionsDir, 'node_modules'));

// ANSI color codes for pretty output
const colors = {
  reset: '\x1b[0m',
  bright: '\x1b[1m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  red: '\x1b[31m',
  cyan: '\x1b[36m'
};

// Utility function to execute shell commands
function runCommand(command, options = {}) {
  console.log(`${colors.cyan}> ${command}${colors.reset}`);
  try {
    execSync(command, { 
      stdio: 'inherit',
      ...options
    });
    return true;
  } catch (error) {
    console.error(`${colors.red}Command failed: ${command}${colors.reset}`);
    if (!options.continueOnError) {
      process.exit(1);
    }
    return false;
  }
}

// Header
console.log(`\n${colors.bright}${colors.cyan}======================================${colors.reset}`);
console.log(`${colors.bright}${colors.cyan}  EatEase Order Update Fix Deployment  ${colors.reset}`);
console.log(`${colors.bright}${colors.cyan}======================================${colors.reset}\n`);

// Step 1: Install dependencies in functions directory
console.log(`${colors.bright}${colors.yellow}Step 1: Installing Firebase Functions dependencies${colors.reset}`);
if (!hasNodeModules) {
  process.chdir(functionsDir);
  runCommand('npm install');
  process.chdir(__dirname);
} else {
  console.log(`${colors.green}Dependencies already installed, skipping...${colors.reset}`);
}

// Step 2: Deploy Firebase Functions
console.log(`\n${colors.bright}${colors.yellow}Step 2: Deploying Firebase Functions${colors.reset}`);
runCommand('firebase deploy --only functions');

// Step 3: Deploy Firestore Security Rules
console.log(`\n${colors.bright}${colors.yellow}Step 3: Deploying Firestore Security Rules${colors.reset}`);
runCommand('firebase deploy --only firestore:rules');

// Success message
console.log(`\n${colors.bright}${colors.green}✓ Deployment completed successfully!${colors.reset}`);
console.log(`\n${colors.cyan}The order update functionality should now work correctly.${colors.reset}`);
console.log(`${colors.cyan}If you still encounter issues, check the following:${colors.reset}`);
console.log(`${colors.cyan}- Firebase Functions logs: ${colors.reset}firebase functions:log`);
console.log(`${colors.cyan}- Ensure cloud_functions package is added to your Flutter project${colors.reset}`);
console.log(`${colors.cyan}- Verify that you're properly authenticated in the Firebase CLI${colors.reset}\n`); 