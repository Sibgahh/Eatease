@echo off
echo Deploying Firebase Functions and Security Rules...

echo Installing dependencies in the functions directory...
cd functions
call npm install

echo Deploying Firebase Functions...
call firebase deploy --only functions

echo Deploying Firestore Security Rules...
cd ..
call firebase deploy --only firestore:rules

echo Deployment completed.
pause 