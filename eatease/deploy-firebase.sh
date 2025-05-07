#!/bin/bash

echo "Deploying Firebase Functions and Security Rules..."

echo "Installing dependencies in the functions directory..."
cd functions
npm install

echo "Deploying Firebase Functions..."
firebase deploy --only functions

echo "Deploying Firestore Security Rules..."
cd ..
firebase deploy --only firestore:rules

echo "Deployment completed." 